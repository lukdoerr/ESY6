#include <cstring>
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>

#define N 19 
#define B 3

unsigned c = 0;
int A[128];

void fill()
{
    for(int i = 0; i < 128; i++)
    {   
        A[i] = 0;
    }
}
void print()
{
    static int cnt = 0;
    printf("%2.d : ", cnt);
    cnt++;

    for(int i=0; i<N; i++)
    {
        printf("%d", A[i]);
    }
    printf("\n");
}


void next(int cnt, int end)
{   
    if(cnt==end) return;

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
        //print();
    }
    next(cnt, end);
}

int main(int argc, char* argv[])
{
    int pre = strlen(argv[1]);
    char* cA = argv[1];

    fill();
    for(int i = N-1; i > N-pre-1; i--)
    {
        int val = (int)cA[i-pre];
        A[i] = val-48;    
    }
    //printf("\n");   
    //print();
    next(0, N-pre);
    printf("Cnt: %d\n", c);


/*    int k = argc-1;
    fill();
    for(int i = N-1; i > N-argc; i--)
    {
        A[i] = strtol(argv[k--], NULL, 10);    
    }
    printf("\n");   
    print();
    next(0, N-argc+1);
    printf("Cnt: %d", c);
*/
    return 0;
}

