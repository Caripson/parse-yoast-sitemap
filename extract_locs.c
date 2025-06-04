#include <stdio.h>
#include <libxml/parser.h>
#include <libxml/xpath.h>

int main(void) {
    xmlDocPtr doc = xmlReadFd(0, NULL, NULL, 0);
    if (!doc) {
        fprintf(stderr, "Failed to parse XML\n");
        return 1;
    }

    xmlXPathContextPtr ctx = xmlXPathNewContext(doc);
    if (!ctx) {
        fprintf(stderr, "Failed to create XPath context\n");
        xmlFreeDoc(doc);
        return 1;
    }

    xmlXPathObjectPtr obj = xmlXPathEvalExpression((xmlChar*)"//*[local-name()='loc']", ctx);
    if (obj && obj->type == XPATH_NODESET && obj->nodesetval) {
        xmlNodeSetPtr nodes = obj->nodesetval;
        for (int i = 0; i < nodes->nodeNr; i++) {
            xmlChar *content = xmlNodeGetContent(nodes->nodeTab[i]);
            if (content) {
                printf("%s\n", content);
                xmlFree(content);
            }
        }
    }

    if (obj)
        xmlXPathFreeObject(obj);
    xmlXPathFreeContext(ctx);
    xmlFreeDoc(doc);
    xmlCleanupParser();
    return 0;
}
