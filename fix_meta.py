import os

classes = [
    'ChangePasswordController',
    'ChangePasswordControllerTest',
    'CommunitiesSelfRegConfirmController',
    'CommunitiesSelfRegConfirmControllerTest',
    'ForgotPasswordController',
    'ForgotPasswordControllerTest',
    'SiteRegisterController',
    'SiteRegisterControllerTest'
]

pages = [
    'ChangePassword',
    'CommunitiesSelfRegConfirm',
    'ForgotPasswordConfirm',
    'SiteRegisterConfirm'
]

class_meta = '''<?xml version="1.0" encoding="UTF-8"?>
<ApexClass xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>60.0</apiVersion>
    <status>Active</status>
</ApexClass>'''

page_meta = '''<?xml version="1.0" encoding="UTF-8"?>
<ApexPage xmlns="http://soap.sforce.com/2006/04/metadata">
    <apiVersion>60.0</apiVersion>
    <availableInTouch>false</availableInTouch>
    <confirmationTokenRequired>false</confirmationTokenRequired>
    <label>{name}</label>
</ApexPage>'''

for c in classes:
    with open(f'force-app/main/default/classes/{c}.cls-meta.xml', 'w', encoding='utf-8') as f:
        f.write(class_meta)

for p in pages:
    with open(f'force-app/main/default/pages/{p}.page-meta.xml', 'w', encoding='utf-8') as f:
        f.write(page_meta.replace('{name}', p))

print('Metadata files fixed!')
