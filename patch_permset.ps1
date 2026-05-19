$xmlFile = "d:\New folder\VJ SFDC\force-app\main\default\permissionsets\SentinelFlow_Admin.permissionset-meta.xml"
[xml]$xml = Get-Content $xmlFile
$ns = "http://soap.sforce.com/2006/04/metadata"

function Add-FieldPerm($field) {
    $newNode = $xml.CreateElement("fieldPermissions", $ns)
    $editable = $xml.CreateElement("editable", $ns)
    $editable.InnerText = "true"
    $fieldNode = $xml.CreateElement("field", $ns)
    $fieldNode.InnerText = $field
    $readable = $xml.CreateElement("readable", $ns)
    $readable.InnerText = "true"
    $newNode.AppendChild($editable) | Out-Null
    $newNode.AppendChild($fieldNode) | Out-Null
    $newNode.AppendChild($readable) | Out-Null
    $xml.PermissionSet.InsertBefore($newNode, $xml.PermissionSet.hasActivationRequired) | Out-Null
}

function Add-ObjPerm($obj) {
    $newNode = $xml.CreateElement("objectPermissions", $ns)
    foreach ($perm in @("allowCreate","allowDelete","allowEdit","allowRead","modifyAllRecords","viewAllRecords")) {
        $pNode = $xml.CreateElement($perm, $ns)
        $pNode.InnerText = "true"
        $newNode.AppendChild($pNode) | Out-Null
    }
    $objNode = $xml.CreateElement("object", $ns)
    $objNode.InnerText = $obj
    $newNode.AppendChild($objNode) | Out-Null
    $xml.PermissionSet.InsertBefore($newNode, $xml.PermissionSet.tabSettings[0]) | Out-Null
}

$fields = @("Incident__c.Integration_Endpoint__c", "Incident__c.Retry_Count__c", "Incident__c.Max_Retry__c", "Incident__c.Auto_Heal_Status__c",
"AI_Decision__c.Incident__c", "AI_Decision__c.Root_Cause__c", "AI_Decision__c.Recommended_Action__c", "AI_Decision__c.Confidence_Score__c", "AI_Decision__c.Impact_Level__c", "AI_Decision__c.Auto_Executed__c", "AI_Decision__c.Matched_Rule__c", "AI_Decision__c.Tenant__c",
"Auto_Heal_Run__c.Incident__c", "Auto_Heal_Run__c.Action_Taken__c", "Auto_Heal_Run__c.Result__c", "Auto_Heal_Run__c.Confidence_Score__c", "Auto_Heal_Run__c.Retry_Attempt__c", "Auto_Heal_Run__c.Detail_Message__c", "Auto_Heal_Run__c.Tenant__c")

foreach ($f in $fields) { Add-FieldPerm $f }

$objs = @("AI_Decision__c", "Auto_Heal_Run__c")
foreach ($o in $objs) { Add-ObjPerm $o }

$xml.Save($xmlFile)
