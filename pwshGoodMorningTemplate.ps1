# 'Chrome' can be replaced w/ 'Edge'/'Firefox' (Comment/Uncomment these lines as needed.)
# URLs to be separated by spaces inside the quotes - This will open new tabs.
# If new window is needed, copy/paste new 'start-process' line(s) for preferred browser, and paste desired URLs in the quotes.

# Reference lines start with one pound ('#')
# Lines that can be uncommented for added functionality start with two pounds ('##')

------------------------------------------------------------------------------------------
# BROWSER SETTINGS:

# Chrome Window 1
start-process -filePath Chrome -argumentList 'https://desiredUrlsGoHere.com'
# Chrome Window 2
##start-process -filePath Chrome -argumentList 'https://desiredUrlsGoHere.com'

# Edge Window 1
##start-process -filePath Edge -argumentList 'https://desiredUrlsGoHere.com'
# Edge Window 2
##start-process -filePath Edge -argumentList 'https://desiredUrlsGoHere.com'

# Firefox Window 1
##start-process -filePath Firefox -argumentList 'https://desiredUrlsGoHere.com'
# Firefox Window 2
##start-process -filePath Firefox -argumentList 'https://desiredUrlsGoHere.com'

------------------------------------------------------------------------------------------
# DESKTOP APPLICATION SETTINGS:

# For desktop applications, place paths to executable inside quotes.
# Additional lines have been pre-added, and just require uncommenting & a path
# More of these lines can be added as needed (One start-process per application)

# ************************************************
# *****IF ADMIN CREDENTIALS ARE REQUIRED********** 
# *****Add '-verb runas' after 'start-process'****
# ************************************************

start-process -filePath "C:\path\To\Application.exe"
##start-process -filePath "C:\path\To\Application.exe"
##start-process -filePath "C:\path\To\Application.exe"
##start-process -filePath "C:\path\To\Application.exe"
##start-process -filePath "C:\path\To\Application.exe"

# Some useful pre-defined paths for everyday applications - uncomment as needed:

# Cherwell
##start-process -filePath "C:\Program Files (x86)\Cherwell Software\Cherwell Service Management\Trebuchet.App.exe"

# MECM
##start-process -verb runas -filePath "C:\Program Files (x86)\ConfigMgrConsole\bin\Microsoft.ConfigurationManagement.exe"

# Notepad++
##start-process -filePath "C:\Program Files\Notepad++\notepad++.exe"