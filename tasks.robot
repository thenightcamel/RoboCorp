# +
*** Settings ***
Documentation    Orders robots from RoboSpareBin Industries, saves order as pdf, saves screenshot to order, embed screenshot, create zip file.
Library    RPA.Excel.Files
Library    RPA.Browser.Selenium
Library    RPA.FileSystem
Library    RPA.HTTP
Library    RPA.PDF
Library    RPA.Tables
Library    String
Library    RPA.Archive
Library    RPA.Robocloud.Secrets
Library    RPA.Dialogs



# -


*** Keywords ***
Open Website
    Open Available Browser    https://robotsparebinindustries.com/#/robot-order
    Maximize Browser Window
*** Keywords ***
Download CSV and read file
    [Arguments]     ${csvFileLink}
    # REPLACED WITH FORM Download    ${csvFileLink}    overwrite=True
    # REPLACED WITH FORM Download    https://robotsparebinindustries.com/orders.csv    overwrite=True
    Read Table From Csv    orders.csv
    ${Get orders}=    Read Table From Csv   orders.csv  header=True
    Wait Until Page Contains Element    id:address
    [Return]    ${Get Orders}

*** Keywords ***
Ask user for the CSV File link
    Create Form     Please provide Orders file link
    Add Text Input    Orders File Link    csvFileLink
    &{response}    Request Response
    #Log     ${response}
    [Return]    ${response["csvFileLink"]}


*** Keywords ***
Fill the form
    Create Form     Please provide Orders file link
    Add Text Input    Orders File Link    csvFileLink
    &{response}    Request Response
    [Return]    ${response["csvFileLink"]} 

*** Keywords ***
Preview the robot
    Wait Until Page Contains Element    id:preview
    Click Button    preview

*** Keywords ***
Submit the order
    Wait Until Page Contains Element    id:robot-preview-image
    Click Button    order
    Sleep   10s
    #prevent screenshots from being taken for errored items
    Mute Run On Failure    Wait Until Element Is Visible    id:receipt
    Run Keyword And Ignore Error    Wait Until Element Is Visible    id:receipt

*** Keywords ***
Fill form
    [Arguments]   ${row}
    Input Text    address    ${row}[Address]
    Select From List By Value    head    ${row}[Head]
    Select Radio Button    body    ${row}[Body]
    ${legsElement}=   Get Element Attribute     class:form-control  outerHTML
    ${legsElemId} =   Fetch From Left   ${legsElement}      " name
    ${legsElemId} =   Fetch From Right   ${legsElemId}      id="
    Input Text    ${legsElemId}   ${row}[Legs]
    Input Text    address   ${row}[Address]

*** Keywords ***
Close the annoying modal
    Wait Until Page Contains Element    class:alert-buttons
    Click Button    OK
    

*** Keywords ***
Check if receipt is generated
    Wait Until Element Is Visible    id:receipt

# +
*** Keywords ***
Store the receipt as a PDF file
    [Arguments]     ${row}
    ${check}=   Is Element Visible     id:receipt
    IF   ${check} == True
            ${order_receipt}=    Get Element Attribute    id:receipt       outerHTML
            Html To Pdf    ${order_receipt}    ${CURDIR}${/}output${/}${row}.pdf
            
    ELSE
            Sleep   5s
            Click Button    order
            Sleep   5s
            ${order_receipt}=    Get Element Attribute    id:receipt       outerHTML
            Html To Pdf    ${order_receipt}    ${CURDIR}${/}output${/}${row}.pdf
            
    END
    [Return]    ${CURDIR}${/}output${/}${row}.pdf
    

# -

*** Keywords ***
Take a screenshot of the robot
    [Arguments]     ${row}
    Wait Until Element Is Visible    id:robot-preview-image
    Screenshot   id:robot-preview-image     ${CURDIR}${/}output${/}${row}.png
    [Return]    ${CURDIR}${/}output${/}${row}.png

*** Keywords ***
Embed the robot screenshot to the receipt PDF file
    [Arguments]    ${screenshot}    ${pdf}
    Open Pdf   ${pdf}
    Add Watermark Image To Pdf    ${screenshot}     ${pdf}
    Close Pdf   ${pdf}

*** Keywords ***
Go to order another robot
    Wait Until Page Contains Element    id:order-another
    Click Button    Order another robot

*** Keywords ***
Logout
    Close All Browsers

*** Keywords ***
Create ZIP
   Archive Folder With ZIP   ${CURDIR}${/}output  ${CURDIR}${/}output${/}receiptPDFs.zip   recursive=True  include=*.pdf  exclude=/.png

*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    ${secret}=    Get Secret    credentials
    Log    ${secret}[username]
    Log    ${secret}[password]
    ${csvFileLink}=     Fill the form
    Open Website
    ${orders}=    Download CSV and read file    ${csvFileLink}
    FOR    ${row}    IN    @{orders}
        Close the annoying modal
        Fill form   ${row}
        Preview the robot
        Wait Until Keyword Succeeds    5x    5s    Submit the order
        ${pdf}=    Wait Until Keyword Succeeds    5x    5s    Store the receipt as a PDF file    ${row}[Order number]
        ${screenshot}=    Take a screenshot of the robot    ${row}[Order number]
        Embed the robot screenshot to the receipt PDF file    ${screenshot}    ${pdf}
        Sleep	5s
        Go to order another robot

    END
    Create ZIP
    Log  Done.
    [Teardown]    Logout
