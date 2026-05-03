String portalUsername = 'sentinelflow.portal.00ddl0000053505uaa@example.com';
String portalEmail = 'vjsf316@gmail.com';
String tempPassword = 'SentinelFlow#2026May!';

User adminUser = [
    SELECT Id
    FROM User
    WHERE Username = 'vjdev@asap.com'
    LIMIT 1
];

Profile portalProfile = [
    SELECT Id
    FROM Profile
    WHERE Name = 'Customer Community Login User'
    LIMIT 1
];

Account portalAccount;
List<Account> accounts = [
    SELECT Id
    FROM Account
    WHERE Name = 'SentinelFlow Portal Users'
    LIMIT 1
];

if (accounts.isEmpty()) {
    portalAccount = new Account(
        Name = 'SentinelFlow Portal Users',
        OwnerId = adminUser.Id
    );
    insert portalAccount;
} else {
    portalAccount = accounts[0];
}

Contact portalContact;
List<Contact> contacts = [
    SELECT Id
    FROM Contact
    WHERE Email = :portalEmail
    AND AccountId = :portalAccount.Id
    LIMIT 1
];

if (contacts.isEmpty()) {
    portalContact = new Contact(
        AccountId = portalAccount.Id,
        FirstName = 'SentinelFlow',
        LastName = 'Portal User',
        Email = portalEmail
    );
    insert portalContact;
} else {
    portalContact = contacts[0];
}

User portalUser;
List<User> users = [
    SELECT Id, Username, IsActive
    FROM User
    WHERE Username = :portalUsername
    LIMIT 1
];

if (users.isEmpty()) {
    portalUser = new User(
        ProfileId = portalProfile.Id,
        ContactId = portalContact.Id,
        Username = portalUsername,
        Email = portalEmail,
        FirstName = 'SentinelFlow',
        LastName = 'Portal User',
        Alias = 'sfportal',
        CommunityNickname = 'sfportal' + String.valueOf(Math.abs(Crypto.getRandomInteger())).left(6),
        TimeZoneSidKey = 'Asia/Kolkata',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US'
    );
    insert portalUser;
} else {
    portalUser = users[0];
    if (!portalUser.IsActive) {
        portalUser.IsActive = true;
        update portalUser;
    }
}

System.setPassword(portalUser.Id, tempPassword);

System.debug('Portal login URL: https://astrosoft2-dev-ed.develop.my.site.com/SentinelFlow/login');
System.debug('Portal username: ' + portalUsername);
System.debug('Temporary password: ' + tempPassword);
