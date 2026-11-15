
#include<stdio.h>
#include<iostream>


int method2(int a, int b)
{
    int c = a + b;
    return c;
}

int method1(int arg)
{
    int variable_inside = arg + 2;
    variable_inside = method2(variable_inside, 2);
    return variable_inside;  // 14
}

int main()
{
    int a = 10;
    a = method1(a);
    return a  << 1;
}

