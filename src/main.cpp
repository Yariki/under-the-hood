
#include<stdio.h>
#include<iostream>

int main(){

    int a = -1;
    int c = -1;
    int b = 2 * a;
    
    if(b > 70)
    {
        c = b + 2;
    } 
    else if(b > 50 ) 
    {
        c = 10;
    }
    else 
    {
        c = 0;
    }

    int i = 0;
    const int counter = 100;
    int arr[counter];

    while(i < counter)
    {
        arr[i] = i;
        i++;
    }

    
    return c;
}
