import os
import glob
import xml.etree.ElementTree as ET

objects_dir = r"d:\New folder\VJ SFDC\force-app\main\default\objects"
perm_file = r"d:\New folder\VJ SFDC\force-app\main\default\permissionsets\SentinelFlow_Admin.permissionset-meta.xml"

# Find all custom objects
all_objects = []
for obj_dir in os.listdir(objects_dir):
    if obj_dir.endswith("__c") or obj_dir.endswith("__mdt") or obj_dir.endswith("__e"):
        all_objects.append(obj_dir)

# Register namespace
ET.register_namespace('', "http://soap.sforce.com/2006/04/metadata")
tree = ET.parse(perm_file)
root = tree.getroot()
ns = {'ns': 'http://soap.sforce.com/2006/04/metadata'}

# Get existing objects
existing_objects = set()
for obj_perm in root.findall('ns:objectPermissions', ns):
    obj_name = obj_perm.find('ns:object', ns).text
    existing_objects.add(obj_name)

existing_fields = set()
for f_perm in root.findall('ns:fieldPermissions', ns):
    f_name = f_perm.find('ns:field', ns).text
    existing_fields.add(f_name)

# Add missing object permissions
for obj in all_objects:
    if obj not in existing_objects:
        obj_perm = ET.Element('{http://soap.sforce.com/2006/04/metadata}objectPermissions')
        ET.SubElement(obj_perm, '{http://soap.sforce.com/2006/04/metadata}allowCreate').text = 'true'
        ET.SubElement(obj_perm, '{http://soap.sforce.com/2006/04/metadata}allowDelete').text = 'true'
        ET.SubElement(obj_perm, '{http://soap.sforce.com/2006/04/metadata}allowEdit').text = 'true'
        ET.SubElement(obj_perm, '{http://soap.sforce.com/2006/04/metadata}allowRead').text = 'true'
        ET.SubElement(obj_perm, '{http://soap.sforce.com/2006/04/metadata}modifyAllRecords').text = 'true'
        ET.SubElement(obj_perm, '{http://soap.sforce.com/2006/04/metadata}object').text = obj
        ET.SubElement(obj_perm, '{http://soap.sforce.com/2006/04/metadata}viewAllRecords').text = 'true'
        root.append(obj_perm)

# Add missing field permissions
for obj in all_objects:
    fields_dir = os.path.join(objects_dir, obj, "fields")
    if os.path.exists(fields_dir):
        for field_file in os.listdir(fields_dir):
            if field_file.endswith(".field-meta.xml"):
                field_name = field_file.replace(".field-meta.xml", "")
                full_field = f"{obj}.{field_name}"
                
                # Check if field is required (required fields shouldn't have fieldPermissions)
                field_tree = ET.parse(os.path.join(fields_dir, field_file))
                req_node = field_tree.getroot().find('ns:required', ns)
                type_node = field_tree.getroot().find('ns:type', ns)
                is_req = req_node is not None and req_node.text == 'true'
                is_master = type_node is not None and type_node.text == 'MasterDetail'
                
                if not is_req and not is_master and full_field not in existing_fields:
                    f_perm = ET.Element('{http://soap.sforce.com/2006/04/metadata}fieldPermissions')
                    ET.SubElement(f_perm, '{http://soap.sforce.com/2006/04/metadata}editable').text = 'true'
                    ET.SubElement(f_perm, '{http://soap.sforce.com/2006/04/metadata}field').text = full_field
                    ET.SubElement(f_perm, '{http://soap.sforce.com/2006/04/metadata}readable').text = 'true'
                    root.append(f_perm)

# Sort elements for clean XML (optional)
# Write back
tree.write(perm_file, xml_declaration=True, encoding='UTF-8')
print("Successfully patched SentinelFlow_Admin.permissionset-meta.xml")
