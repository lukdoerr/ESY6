#include <iostream>
#include <SDL2/SDL.h>
#include <signal.h>
#include <complex>
using namespace std;

const complex<double> c {-0.751, +0.02225};
const int N = 3000, L = 2;
const int xmin = -1.5, xmax = 1.5;
const int imin = 0, imax = 15000;

const double T = (double)(xmax - xmin) / (double)(imax - imin);



complex<double> f(complex<double> z)
{
    return (z*z) + c;
}

int denormalize(double x)
{
    return (xmin - x) / T;
}


double normalize(int i)
{   
    double x = xmin + (i - imin) * (double)T;
    return x;
}


static inline 
double abs_sqr(complex<double> z)
{
    return z.real() * z.real() + z.imag() * z.imag();
}


int main ()
{   
    cout << "P1" << '\n' << imax << ' ' << imax << '\n';
    for(int iy=0; iy < imax; iy++)
    {
        double y = normalize(iy);
        for(int ix = 0; ix < imax; ix++)
        {
            double x = normalize(ix);
            complex<double> z(x, y); 
            int cnt = 0;
            do
            {
                z = f(z);
            }while((abs_sqr(z) < L*L) && ++cnt < N);
            
            if(cnt == N){
                cout << '1' << ' ';
            }
            else cout << '0' << ' ';
        }
        cout << '\n';
    }
}
