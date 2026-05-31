import xml.etree.ElementTree as ET
import sys

ET.register_namespace('', "http://soap.sforce.com/2006/04/metadata")
tree = ET.parse("force-app/main/default/permissionsets/SentinelFlow_Admin.permissionset-meta.xml")
root = tree.getroot()
ns = {'ns': 'http://soap.sforce.com/2006/04/metadata'}

# Remove the incorrectly placed ones at the end by just removing all elements and re-adding them in order
elements = list(root)
for el in elements:
    root.remove(el)

order = [
    'description', 'classAccesses', 'customPermissions', 'fieldPermissions', 'flowAccesses',
    'hasActivationRequired', 'label', 'objectPermissions', 'pageAccesses', 'recordTypeVisibilities',
    'tabSettings', 'userPermissions'
]

# Sort by the tag name without namespace, then by a key field inside it
def get_sort_key(el):
    tag = el.tag.split('}')[-1]
    tag_order = order.index(tag) if tag in order else 99
    
    inner_key = ""
    if tag == 'fieldPermissions':
        inner_key = el.find('ns:field', ns).text
    elif tag == 'objectPermissions':
        inner_key = el.find('ns:object', ns).text
    elif tag == 'tabSettings':
        inner_key = el.find('ns:tab', ns).text
    
    return (tag_order, inner_key)

# Filter out duplicates
seen = set()
unique_elements = []
for el in elements:
    tag = el.tag.split('}')[-1]
    inner_key = ""
    if tag == 'fieldPermissions':
        inner_key = el.find('ns:field', ns).text
    elif tag == 'objectPermissions':
        inner_key = el.find('ns:object', ns).text
    elif tag == 'tabSettings':
        inner_key = el.find('ns:tab', ns).text
        
    ident = f"{tag}_{inner_key}"
    if ident not in seen:
        seen.add(ident)
        unique_elements.append(el)

unique_elements.sort(key=get_sort_key)

for el in unique_elements:
    root.append(el)

tree.write("force-app/main/default/permissionsets/SentinelFlow_Admin.permissionset-meta.xml", encoding="UTF-8", xml_declaration=True)
print("Sorted XML.")
