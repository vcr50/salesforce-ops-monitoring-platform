global class SSORegHandler implements Auth.RegistrationHandler {
    
    global User createUser(Id portalId, Auth.UserData data) {
        // 1. Try to find the exact username match first
        List<User> existingUsers = [SELECT Id, Profile.UserType FROM User WHERE Username = :data.username LIMIT 1];
        if (!existingUsers.isEmpty()) {
            if (portalId != null && existingUsers[0].Profile.UserType == 'Standard') {
                // Skip internal user for community login to prevent redirect loop
            } else {
                return existingUsers[0];
            }
        }

        // 2. Fallback to matching by Email
        if (String.isNotBlank(data.email)) {
            List<User> emailUsers = [SELECT Id, Profile.UserType FROM User WHERE Email = :data.email AND IsActive = true LIMIT 1];
            if (!emailUsers.isEmpty()) {
                if (portalId != null && emailUsers[0].Profile.UserType == 'Standard') {
                    // Skip internal user for community login to prevent redirect loop
                } else {
                    return emailUsers[0];
                }
            }
        }

        // 3. If no user is found, automatically provision a new one
        // Ensure a dummy Account exists to hold external portal Contacts
        Account portalAccount;
        List<Account> accounts = [SELECT Id FROM Account WHERE Name = 'SentinelFlow Portal Users' LIMIT 1];
        if (accounts.isEmpty()) {
            portalAccount = new Account(Name = 'SentinelFlow Portal Users');
            insert portalAccount;
        } else {
            portalAccount = accounts[0];
        }

        // Create Contact
        Contact c = new Contact();
        c.AccountId = portalAccount.Id;
        c.FirstName = String.isNotBlank(data.firstName) ? data.firstName : 'Portal';
        c.LastName  = String.isNotBlank(data.lastName) ? data.lastName : 'User';
        c.Email     = String.isNotBlank(data.email) ? data.email : ('user' + Crypto.getRandomInteger() + '@sentinelflow.com');
        insert c;

        // Create User
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Customer Community Login User' LIMIT 1];
        
        User u = new User();
        u.ProfileId = p.Id;
        String desiredUsername = String.isNotBlank(data.username) ? data.username : c.Email;
        if (portalId != null && !desiredUsername.endsWith('.community')) {
            desiredUsername += '.community';
        }
        u.Username = desiredUsername;
        u.Email = c.Email;
        u.FirstName = c.FirstName;
        u.LastName = c.LastName;
        
        String alias = (u.FirstName.substring(0, 1) + u.LastName).left(8);
        u.Alias = alias;
        u.CommunityNickname = alias + String.valueOf(Crypto.getRandomInteger()).substring(0, 4);
        u.TimeZoneSidKey = 'America/Los_Angeles';
        u.LocaleSidKey = 'en_US';
        u.EmailEncodingKey = 'UTF-8';
        u.LanguageLocaleKey = 'en_US';
        u.ContactId = c.Id;
        
        return u; 
    }

    global void updateUser(Id userId, Id portalId, Auth.UserData data) {
        // Automatically sync details if needed
        User u = new User(Id = userId);
        boolean changed = false;
        if (String.isNotBlank(data.firstName)) {
            u.FirstName = data.firstName;
            changed = true;
        }
        if (String.isNotBlank(data.lastName)) {
            u.LastName = data.lastName;
            changed = true;
        }
        if (changed) {
            update u;
        }
    }
}
