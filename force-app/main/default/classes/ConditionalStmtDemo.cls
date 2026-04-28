public class ConditionalStmtDemo {
    public static void max(Integer num1, Integer num2) {
        Integer result;
        result = num1 > num2 ? num1 : num2;
        System.debug('Maximum =' + result);
    }
}
