/**
 * @description AccountRecord - Utility class for Account and Contact data operations.
 * @author Tomcodex
 * @version 1.0
 */
@SuppressWarnings('PMD.ApexCRUDViolation')
public class AccountRecord {

    /**
     * @description Inserts a new Account record with the specified details.
     * @param name    The Account name.
     * @param rating  The Account rating.
     * @param website The Account website URL.
     * @return        The Id of the newly created Account, or null on failure.
     */
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

    /**
     * @description Creates a Contact linked to a newly inserted Account.
     */
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

