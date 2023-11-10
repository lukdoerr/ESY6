#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>

#define N 19
#define B 3

unsigned c = 0;
int A[N+1];

void fill()
{
    for(int i = 0; i <=N; i++)
    {
        A[i] = 0;
    }
}
void print()
{
    static int cnt = 0;
    printf("%d : ", cnt);
    cnt++;
    for(int i=0; i<N; i++)
    {
        printf("%d", A[i]);
    }
    printf("\n");
}

void next(int cnt)
{   
    if(cnt==N) return;

    if(A[cnt] == B-1)
    {
        A[cnt] = 0;
        cnt++;
    }
    else 
    {
        A[cnt]++;
        cnt=0;
        c++;
        //print(A);
    }
    next( cnt);
}

int main(int argc, char* argv[])
{
    fill();
    //print(&A);
    next(0);
    printf("Cnt: %d", c);
    return 0;
}

