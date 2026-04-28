public class stringCheckController {
    public static Boolean keywordExist(String input) {
        if (String.isBlank(input)) {
            return false;
        }

        if (input.contains('salesforce')) {
            return true;
        }

        return false;
    }
}
