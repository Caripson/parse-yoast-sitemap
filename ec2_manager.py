import argparse
import json
import os
import time
from pathlib import Path

import boto3
import paramiko


DEFAULT_CONFIG = {
    "ami": "ami-1234567890abcdef0",
    "instance_type": "t3.micro",
    "key_name": "my-key",
    "security_groups": [],
    "ssh_user": "ec2-user",
    "ssh_key_path": "~/.ssh/id_rsa",
    "repo_url": "https://github.com/Caripson/parse-yoast-sitemap.git",
    "server_port": 8080,
}


def load_config(path: str) -> dict:
    if not os.path.exists(path):
        return DEFAULT_CONFIG
    with open(path, "r") as f:
        data = json.load(f)
    cfg = DEFAULT_CONFIG.copy()
    cfg.update(data)
    return cfg


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
    ec2 = boto3.resource("ec2")
    instances = ec2.create_instances(
        ImageId=cfg["ami"],
        InstanceType=cfg["instance_type"],
        KeyName=cfg["key_name"],
        SecurityGroupIds=cfg.get("security_groups", []),
        MinCount=1,
        MaxCount=1,
    )
    inst = instances[0]
    print(f"Starting instance {inst.id} ...")
    inst.wait_until_running()
    inst.reload()
    ip = inst.public_ip_address
    print(f"Instance running at {ip}")

    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(
        ip,
        username=cfg.get("ssh_user", "ec2-user"),
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

    # start server
    start_cmd = (
        "cd project && nohup python3 -m yoast_monitor.serve_reports "
        "server_config.json > server.log 2>&1 &"
    )
    ssh.exec_command(start_cmd)
    ssh.close()

    wait_for_port(ip, cfg.get("server_port", 8080))
    print(f"Server running at http://{ip}:{cfg.get('server_port',8080)}")
    print(f"Instance ID: {inst.id}")


def stop(instance_id: str) -> None:
    ec2 = boto3.resource("ec2")
    inst = ec2.Instance(instance_id)
    print(f"Terminating {instance_id} ...")
    inst.terminate()
    inst.wait_until_terminated()
    print("Instance terminated")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Manage EC2 deployment")
    sub = ap.add_subparsers(dest="cmd", required=True)
    st = sub.add_parser("start")
    st.add_argument("--config", default="ec2_config.json")

    sp = sub.add_parser("stop")
    sp.add_argument("instance_id")

    args = ap.parse_args()
    if args.cmd == "start":
        start(args.config)
    elif args.cmd == "stop":
        stop(args.instance_id)
