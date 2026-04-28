public class Square {
    Decimal a;

    public Square(Decimal a) {
        this.a = a;
    }

    public void area() {
        Decimal area;
        area = a * a;
        System.debug('Area =' + area);
    }

    public void Perimeter() {
        Decimal peri;
        peri = 4 * a;
        System.debug('Perimeter =' + peri);
    }
}
