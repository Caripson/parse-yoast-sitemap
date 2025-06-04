import argparse
import json
import os
import subprocess
import time
from pathlib import Path

DEFAULT_CONFIG = {
    "ami": "ami-1234567890abcdef0",
    "instance_type": "t3a.micro",
    "key_name": "my-key",
    "security_group": "sg-0123456789abcdef0",
    "ssh_user": "ubuntu",
    "ssh_key_path": "~/.ssh/id_rsa",
    "repo_url": "https://github.com/Caripson/parse-yoast-sitemap.git",
    "server_port": 8080,
    "allowed_ip": "0.0.0.0/0",
}


def load_config(path: str) -> dict:
    if not os.path.exists(path):
        return DEFAULT_CONFIG
    with open(path, "r") as f:
        data = json.load(f)
    cfg = DEFAULT_CONFIG.copy()
    cfg.update(data)
    return cfg


def run(cmd: list[str]) -> str:
    out = subprocess.check_output(cmd, text=True)
    return out.strip()


def wait_for_port(host: str, port: int, timeout: int = 300) -> None:
    import socket

    start = time.time()
    while time.time() - start < timeout:
        try:
            with socket.create_connection((host, port), timeout=5):
                return
        except OSError:
            time.sleep(5)
    raise RuntimeError(f"Timed out waiting for {host}:{port}")


def start(cfg_path: str) -> None:
    cfg = load_config(cfg_path)
    sg = cfg["security_group"]
    allowed_ip = cfg.get("allowed_ip", "0.0.0.0/0")
    # Open the configured HTTP port for the given IP range
    subprocess.run(
        [
            "aws",
            "ec2",
            "authorize-security-group-ingress",
            "--group-id",
            sg,
            "--protocol",
            "tcp",
            "--port",
            str(cfg.get("server_port", 8080)),
            "--cidr",
            allowed_ip,
        ],
        check=False,
    )

    instance_id = run(
        [
            "aws",
            "ec2",
            "run-instances",
            "--image-id",
            cfg["ami"],
            "--instance-type",
            cfg["instance_type"],
            "--key-name",
            cfg["key_name"],
            "--security-group-ids",
            sg,
            "--query",
            "Instances[0].InstanceId",
            "--output",
            "text",
        ]
    )
    print(f"Starting instance {instance_id} ...")
    subprocess.check_call(["aws", "ec2", "wait", "instance-running", "--instance-ids", instance_id])
    ip = run(
        [
            "aws",
            "ec2",
            "describe-instances",
            "--instance-ids",
            instance_id,
            "--query",
            "Reservations[0].Instances[0].PublicIpAddress",
            "--output",
            "text",
        ]
    )
    print(f"Instance running at {ip}")

    import paramiko

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(
        ip,
        username=cfg.get("ssh_user", "ubuntu"),
        key_filename=os.path.expanduser(cfg.get("ssh_key_path")),
    )

    repo = cfg.get("repo_url")
    cmds = [
        "sudo apt-get update",
        "sudo apt-get install -y git python3-pip",
        f"git clone {repo} project",
        "cd project && pip3 install -r requirements.txt psutil",
    ]
    for cmd in cmds:
        print(f"Running: {cmd}")
        ssh.exec_command(cmd)
        time.sleep(2)

    # copy local config files
    sftp = ssh.open_sftp()
    for name in ["config.json", "server_config.json"]:
        local = Path(name)
        if local.exists():
            print(f"Uploading {name}")
            sftp.put(str(local), f"project/{name}")
    sftp.close()

    start_cmd = (
        "cd project && nohup python3 -m yoast_monitor.serve_reports "
        "server_config.json > server.log 2>&1 &"
    )
    ssh.exec_command(start_cmd)
    ssh.close()

    wait_for_port(ip, cfg.get("server_port", 8080))
    print(f"Server running at http://{ip}:{cfg.get('server_port',8080)}")
    print(f"Instance ID: {instance_id}")


def stop(instance_id: str) -> None:
    print(f"Terminating {instance_id} ...")
    subprocess.check_call(["aws", "ec2", "terminate-instances", "--instance-ids", instance_id])
    subprocess.check_call(["aws", "ec2", "wait", "instance-terminated", "--instance-ids", instance_id])
    print("Instance terminated")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Manage EC2 deployment via AWS CLI")
    sub = ap.add_subparsers(dest="cmd", required=True)
    st = sub.add_parser("start")
    st.add_argument("--config", default="ec2_cli_config.json")

    sp = sub.add_parser("stop")
    sp.add_argument("instance_id")

    args = ap.parse_args()
    if args.cmd == "start":
        start(args.config)
    elif args.cmd == "stop":
        stop(args.instance_id)
