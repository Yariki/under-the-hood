
#include<stdio.h>
#include<iostream>

class TestClass 
{
    public: 
        int m_age;
        double m_precision;
        TestClass() : m_age(0), m_precision(0.0) {}
    
        void printAge()
        {
            std::cout << m_age << std::endl;
        }
};


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

int method3()
{
    TestClass *testClass = new TestClass();
    testClass->m_age = 25;
    testClass->printAge();

    delete testClass;
}


int main()
{
    int a = 10;
    a = method1(a);

    for(int i = 0; i < 16;i++)
    {
        std::cout << a << std::endl;
    }

    method3();
    
    return a  << 1;
}

