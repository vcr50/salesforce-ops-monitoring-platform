public class AccountRecord {
    public static ID insertData(String name, String rating, String website) {
        try {
            Account acc = new Account();
            acc.Name = name;
            acc.Rating = rating;
            acc.Website = website;

            insert acc;
            return acc.Id;
        } catch (Exception e) {
            System.debug('Error inserting Account: ' + e.getMessage());
            return null;
        }
    }

    public static void insertContact() {
        try {
            Id accId = insertData('nitro 6', 'hot', 'www.example.com');
            if (accId != null) {
                Contact con = new Contact(FirstName = 'Contact 1', LastName = 'Con 1');
                con.AccountId = accId;
                insert con;
            } else {
                System.debug('Account insertion failed, skipping contact creation.');
            }
        } catch (Exception e) {
            System.debug('Error inserting Contact: ' + e.getMessage());
        }
    }
}
