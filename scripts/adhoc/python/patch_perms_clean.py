import os

perm_file = r"d:\New folder\VJ SFDC\force-app\main\default\permissionsets\SentinelFlow_Admin.permissionset-meta.xml"

# Objects to ensure are present
objects_to_add = [
    "Revenue_Risk__c", "Flow_Health__c", "Auto_Heal_Run__c", 
    "AI_Decision__c", "Integration_Endpoint__c"
]

with open(perm_file, "r") as f:
    content = f.read()

# Add missing objects
for obj in objects_to_add:
    if f"<object>{obj}</object>" not in content:
        # Create block
        block = f"""    <objectPermissions>
        <allowCreate>true</allowCreate>
        <allowDelete>true</allowDelete>
        <allowEdit>true</allowEdit>
        <allowRead>true</allowRead>
        <modifyAllRecords>true</modifyAllRecords>
        <object>{obj}</object>
        <viewAllRecords>true</viewAllRecords>
    </objectPermissions>
"""
        content = content.replace("</PermissionSet>", block + "</PermissionSet>")

# Add fields
# Let's dynamically add all fields for these objects
objects_dir = r"d:\New folder\VJ SFDC\force-app\main\default\objects"
for obj in objects_to_add:
    fields_dir = os.path.join(objects_dir, obj, "fields")
    if os.path.exists(fields_dir):
        for field_file in os.listdir(fields_dir):
            if field_file.endswith(".field-meta.xml"):
                field_name = field_file.replace(".field-meta.xml", "")
                full_field = f"{obj}.{field_name}"
                
                if f"<field>{full_field}</field>" not in content:
                    # check if required
                    with open(os.path.join(fields_dir, field_file), "r") as ffield:
                        ffield_content = ffield.read()
                        if "<required>true</required>" not in ffield_content and "<type>MasterDetail</type>" not in ffield_content:
                            block = f"""    <fieldPermissions>
        <editable>true</editable>
        <field>{full_field}</field>
        <readable>true</readable>
    </fieldPermissions>
"""
                            content = content.replace("</PermissionSet>", block + "</PermissionSet>")

with open(perm_file, "w") as f:
    f.write(content)

print("Successfully appended cleanly to SentinelFlow_Admin.permissionset-meta.xml")
