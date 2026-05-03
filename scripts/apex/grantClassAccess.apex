try {
    Id classId = [
        SELECT Id
        FROM ApexClass
        WHERE Name = 'SentinelFlowLoginController'
        LIMIT 1
    ].Id;

    Set<Id> profileIds = new Set<Id>();

    for (Site siteRecord : [
        SELECT GuestUser.ProfileId
        FROM Site
        WHERE Name = 'SentinelFlow'
        LIMIT 1
    ]) {
        profileIds.add(siteRecord.GuestUser.ProfileId);
    }

    for (Profile profileRecord : [
        SELECT Id
        FROM Profile
        WHERE Name IN ('SentinelFlow Profile', 'SEOMP Portal Profile', 'Customer Community Login User')
    ]) {
        profileIds.add(profileRecord.Id);
    }

    List<SetupEntityAccess> grants = new List<SetupEntityAccess>();
    for (PermissionSet profilePermissionSet : [
        SELECT Id, Profile.Name
        FROM PermissionSet
        WHERE ProfileId IN :profileIds
    ]) {
        List<SetupEntityAccess> existing = [
            SELECT Id
            FROM SetupEntityAccess
            WHERE ParentId = :profilePermissionSet.Id
            AND SetupEntityId = :classId
            LIMIT 1
        ];

        if (existing.isEmpty()) {
            grants.add(new SetupEntityAccess(
                ParentId = profilePermissionSet.Id,
                SetupEntityId = classId
            ));
            System.debug('Queued access grant for profile: ' + profilePermissionSet.Profile.Name);
        } else {
            System.debug('Access already exists for profile: ' + profilePermissionSet.Profile.Name);
        }
    }

    if (!grants.isEmpty()) {
        insert grants;
        System.debug('Access grants inserted: ' + grants.size());
    } else {
        System.debug('No new access grants needed.');
    }
} catch (Exception e) {
    System.debug('Error: ' + e.getMessage());
}
