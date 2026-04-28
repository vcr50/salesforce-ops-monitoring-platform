public class LoopDemo {
    public static void SumOfNaturalNums(Integer n) {
        Integer i;
        Integer sum = 0;
        for (i = 1; i <= n; i++) {
            sum = sum + i;
            System.debug('sum=' + sum);
        }
    }
}
