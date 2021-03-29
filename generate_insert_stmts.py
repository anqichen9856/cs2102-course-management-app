import pandas as pd
import re

def make_values(row, n):
    l = []
    for i in range(n):
        val = str(row[i])
        if val == '' or val == 'nan' or val == 'NaT':
            l.append('NULL')
        elif re.match(r'^[0-9]+(\.[0-9]+)*$', val):
            l.append(val)
        elif ' 00:00:00' in val:
            l.append('\'' + val[:-9] + '\'')
        else:
            l.append('\'' + val + '\'')
    return ', '.join(l)

def make_stmts_for_table(df, name):
    l = ['--' + name]
    n = len(df.columns)
    # for i, col in enumerate(df.columns):
    #     if 'Unnamed' in col:
    #         n = i
    #         break
    for index, row in df.iterrows():
        values = make_values(row, n)
        l.append('INSERT INTO ' + name + ' VALUES (' + values + ');')
    return '\n'.join(l)

workbook = pd.read_excel('data.xlsx', sheet_name=None, engine='openpyxl')
f = open('data.sql', 'w+')
for name, df in workbook.items():
    f.write(make_stmts_for_table(df, name) + '\n\n')

# For individual sheet testing    
# df = pd.read_excel('data.xlsx', sheet_name='Cancels', engine='openpyxl')
# f = open('data.sql', 'a')
# f.write(make_stmts_for_table(df, 'Test') + '\n\n')