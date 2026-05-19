import os
import xml.etree.ElementTree as ET

objects_dir = r"d:\New folder\VJ SFDC\force-app\main\default\objects"
perm_file = r"d:\New folder\VJ SFDC\force-app\main\default\permissionsets\SentinelFlow_Admin.permissionset-meta.xml"

all_objects = [d for d in os.listdir(objects_dir) if d.endswith("__c") or d.endswith("__mdt") or d.endswith("__e")]

ET.register_namespace('', "http://soap.sforce.com/2006/04/metadata")
tree = ET.parse(perm_file)
root = tree.getroot()
ns = {'ns': 'http://soap.sforce.com/2006/04/metadata'}

existing_obj_names = set()
obj_perms = []
for obj_perm in root.findall('ns:objectPermissions', ns):
    existing_obj_names.add(obj_perm.find('ns:object', ns).text)
    obj_perms.append(obj_perm)
    root.remove(obj_perm)

existing_field_names = set()
field_perms = []
for f_perm in root.findall('ns:fieldPermissions', ns):
    existing_field_names.add(f_perm.find('ns:field', ns).text)
    field_perms.append(f_perm)
    root.remove(f_perm)

tab_settings = []
for t_set in root.findall('ns:tabSettings', ns):
    tab_settings.append(t_set)
    root.remove(t_set)

# We actually need to clear obj_perms for __e and __mdt from previous bad run and recreate them
new_obj_perms = []
for op in obj_perms:
    obj_name = op.find('{http://soap.sforce.com/2006/04/metadata}object').text
    if obj_name.endswith("__e") or obj_name.endswith("__mdt"):
        existing_obj_names.remove(obj_name)
    else:
        new_obj_perms.append(op)
obj_perms = new_obj_perms

for obj in all_objects:
    if obj not in existing_obj_names:
        obj_perm = ET.Element('{http://soap.sforce.com/2006/04/metadata}objectPermissions')
        ET.SubElement(obj_perm, '{http://soap.sforce.com/2006/04/metadata}allowCreate').text = 'true' if not obj.endswith("__mdt") else 'false'
        ET.SubElement(obj_perm, '{http://soap.sforce.com/2006/04/metadata}allowDelete').text = 'true' if obj.endswith("__c") else 'false'
        ET.SubElement(obj_perm, '{http://soap.sforce.com/2006/04/metadata}allowEdit').text = 'true' if obj.endswith("__c") else 'false'
        ET.SubElement(obj_perm, '{http://soap.sforce.com/2006/04/metadata}allowRead').text = 'true'
        ET.SubElement(obj_perm, '{http://soap.sforce.com/2006/04/metadata}modifyAllRecords').text = 'true' if obj.endswith("__c") else 'false'
        ET.SubElement(obj_perm, '{http://soap.sforce.com/2006/04/metadata}object').text = obj
        ET.SubElement(obj_perm, '{http://soap.sforce.com/2006/04/metadata}viewAllRecords').text = 'true' if obj.endswith("__c") else 'false'
        obj_perms.append(obj_perm)
        existing_obj_names.add(obj)

for obj in all_objects:
    if obj.endswith("__c"):
        fields_dir = os.path.join(objects_dir, obj, "fields")
        if os.path.exists(fields_dir):
            for field_file in os.listdir(fields_dir):
                if field_file.endswith(".field-meta.xml"):
                    field_name = field_file.replace(".field-meta.xml", "")
                    full_field = f"{obj}.{field_name}"
                    
                    field_tree = ET.parse(os.path.join(fields_dir, field_file))
                    f_root = field_tree.getroot()
                    req_node = f_root.find('ns:required', ns)
                    type_node = f_root.find('ns:type', ns)
                    is_req = req_node is not None and req_node.text == 'true'
                    is_master = type_node is not None and type_node.text == 'MasterDetail'
                    
                    if not is_req and not is_master and full_field not in existing_field_names:
                        f_perm = ET.Element('{http://soap.sforce.com/2006/04/metadata}fieldPermissions')
                        ET.SubElement(f_perm, '{http://soap.sforce.com/2006/04/metadata}editable').text = 'true'
                        ET.SubElement(f_perm, '{http://soap.sforce.com/2006/04/metadata}field').text = full_field
                        ET.SubElement(f_perm, '{http://soap.sforce.com/2006/04/metadata}readable').text = 'true'
                        field_perms.append(f_perm)
                        existing_field_names.add(full_field)

field_perms.sort(key=lambda x: x.find('{http://soap.sforce.com/2006/04/metadata}field').text)
for fp in field_perms:
    root.append(fp)

obj_perms.sort(key=lambda x: x.find('{http://soap.sforce.com/2006/04/metadata}object').text)
for op in obj_perms:
    root.append(op)

tab_settings.sort(key=lambda x: x.find('{http://soap.sforce.com/2006/04/metadata}tab').text)
for ts in tab_settings:
    root.append(ts)

tree.write(perm_file, xml_declaration=True, encoding='UTF-8')
print("Successfully patched and sorted SentinelFlow_Admin.permissionset-meta.xml for Platform Events")
