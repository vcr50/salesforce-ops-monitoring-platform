import xml.etree.ElementTree as ET
ET.register_namespace('', "http://soap.sforce.com/2006/04/metadata")
tree = ET.parse("force-app/main/default/permissionsets/SentinelFlow_Admin.permissionset-meta.xml")
root = tree.getroot()
ns = {'ns': 'http://soap.sforce.com/2006/04/metadata'}

fields = [
    "Audit_Trail__c.Record_Id__c", "Audit_Trail__c.Tenant__c"
]

for f in fields:
    fp = ET.Element("{http://soap.sforce.com/2006/04/metadata}fieldPermissions")
    ed = ET.SubElement(fp, "{http://soap.sforce.com/2006/04/metadata}editable")
    ed.text = "true"
    fd = ET.SubElement(fp, "{http://soap.sforce.com/2006/04/metadata}field")
    fd.text = f
    rd = ET.SubElement(fp, "{http://soap.sforce.com/2006/04/metadata}readable")
    rd.text = "true"
    root.insert(20, fp)

tree.write("force-app/main/default/permissionsets/SentinelFlow_Admin.permissionset-meta.xml", encoding="UTF-8", xml_declaration=True)
