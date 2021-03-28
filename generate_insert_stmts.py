import pandas as pd
import re

def make_values(row, n):
    l = []
    for i in range(n):
        val = str(row[i])
        if val == '':
            l.append('NULL')
        elif re.match(r'[0-9]+(\.[0-9]+)*', val):
            l.append(val)
        else:
            l.append('\'' + val + '\'')
    return ', '.join(l)

def make_stmts_for_table(df, name):
    l = ['--' + name]
    n = len(df. columns)
    for index, row in df.iterrows():
        values = make_values(row, n)
        l.append('INSERT INTO TABLE ' + name + ' VALUES (' + values + ');')
    return '\n'.join(l)

workbook = pd.read_excel('data.xlsx', sheet_name=None, engine='openpyxl')
f = open('data.sql', 'a')
for name, df in workbook.items():
    f.write(make_stmts_for_table(df, name) + '\n\n')
    
    