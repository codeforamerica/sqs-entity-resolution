import db

print('==================================================')
print('Are you sure you want to set all TODO rows in the export_tracker tabled to SKIPPED? If so, type YES:')
ans = input('>')
if ans == 'YES':
    db.shift_todo_to_skipped()
    print('Done.')
else:
    print('Nothing was done. Everything was left as-is.')
