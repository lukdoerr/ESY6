#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>

FILE *fp;

unsigned c = 0;
int A[128];

void fill(int N)
{
    for(int i = 0; i <=N; i++)
    {
        A[i] = 0;
    }
}
void print(int N)
{
    static int cnt = 0;
    printf("%d : ", cnt);
    cnt++;

    fputs("./worker ", fp);

    for(int i=0; i<N; i++)
    {
        int value = A[i];
        fprintf(fp, "%d", value);
        printf("%d", A[i]);
    }
    fputs("\n", fp);
    printf("\n");
}


void prefix()
{
    
}


void next(int cnt, int B, int N)
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
        print(N);
    }
    next(cnt, B, N);
}

int main(int argc, char* argv[])
{
    long B = strtol(argv[1], NULL, 10);
    long N = strtol(argv[2], NULL, 10); 
    
    fp = fopen("./fscript.sh", "w+");
    
    fill(N);
    print(N);
    next(0, B, N);
    printf("Cnt: %d", c);

    fclose(fp);
    return 0;
}

