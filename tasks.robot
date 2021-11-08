# +
*** Settings ***
Documentation    Automation for bulk order placements in Build a Robot site
...              
...              Usage Flow:
...              Ask the user for the path of file containing all order details
...              Display path of the order receipts once all orders are placed
...              
...              Logic Flow:
...              Download the orders file from the path specified
...              Fill-out the order form for each order indicated in the orders file
...              - Close recurring pop-up modals
...              - Re-attempt order submission if error is encountered
...              Generate a PDF file containing the following infomration
...              - Order receipt
...              - Preview of the robot ordered
...              Close Browser

Library          RPA.Archive
Library          RPA.Browser.Selenium
Library          RPA.Dialogs
Library          RPA.FileSystem
Library          RPA.HTTP
Library          RPA.PDF
Library          RPA.Robocorp.Vault
Library          RPA.Tables 
# -


*** Keywords ***
Get Orders File From User
    Add text input    name=orders_file    label=Orders file path
    ${input}=    Run Dialog
    [Return]    ${input.orders_file}

*** Keywords ***
Get Build A Robot Url From Vault
    ${build_a_robot_url}=    Get Secret    website_credentials
    [Return]    ${build_a_robot_url["build_a_robot_url"]}

*** Keywords ***
Download Orders File
    [Arguments]    ${file}
    Download    url=${file}    target_file=${CURDIR}${/}output${/}orders.csv    overwrite=True

*** Keywords ***
Open Intranet Website
    [Arguments]    ${build_a_robot_url}
    Open Available Browser    url=${build_a_robot_url}

*** Keywords ***
Close Annoying Modal
    Click Button    locator=class:btn.btn-dark

*** Keywords ***
Click Submit Button Resiliently
    FOR    ${i}    IN RANGE    9999999
        Click Button    locator=id:order
        ${submit_button_visible}=    Is Element Visible    locator=id:order
        Exit For Loop If    ${submit_button_visible} == False
    END

*** Keywords ***
Submit Form For One Order
    [Arguments]    ${order}
    Select From List By Value    id:head    ${order}[Head]    
    ${order_body_selector}=    Catenate    SEPARATOR=    id:id-body-    ${order}[Body]
    Click Element    ${order_body_selector}    
    Input Text    css:input[placeholder="Enter the part number for the legs"]    ${order}[Legs]
    Input Text    id:address    ${order}[Address]
    Click Button    locator=id:preview
    Click Submit Button Resiliently

*** Keywords ***
Save Receipt To PDF
    [Arguments]    ${order_id}
    Wait Until Element Is Visible    locator=id:receipt
    ${receipt_html}=    Get Element Attribute    locator=id:receipt    attribute=outerHTML
    ${receipt_pdf_filename}=    Catenate    SEPARATOR=    ${order_id}    _order_receipt.pdf
    HTML to PDF    ${receipt_html}    ${CURDIR}${/}output${/}${receipt_pdf_filename}

*** Keywords ***
Save Robot Preview To File
    [Arguments]    ${order_id}    
    ${robot_image_file_prefix}=    Catenate    SEPARATOR=    ${order_id}    _robot_preview.png
    Wait Until Element Is Visible    locator=css:div#robot-preview-image>img[alt="Head"]
    Wait Until Element Is Visible    locator=css:div#robot-preview-image>img[alt="Body"]
    Wait Until Element Is Visible    locator=css:div#robot-preview-image>img[alt="Legs"]
    Screenshot    locator=id:robot-preview-image    filename=${CURDIR}${/}output${/}${robot_image_file_prefix}    

*** Keywords ***
Generate Detailed Receipt PDF
    [Arguments]    ${order_id}
    Save Receipt To PDF    ${order_id}
    Save Robot Preview To File    ${order_id}
    ${receipt_file}=    Catenate    SEPARATOR=    ${order_id}    _order_receipt.pdf
    ${robot_preview_file}=    Catenate    SEPARATOR=    ${order_id}    _robot_preview.png
    ${files}=    Create List    ${CURDIR}${/}output${/}${robot_preview_file}
    Add Files To PDF
    ...    files=${files}
    ...    target_document=${CURDIR}${/}output${/}${receipt_file}
    ...    append=True

*** Keywords ***
Process One Order
    [Arguments]    ${order}
    Submit Form For One Order    ${order}
    Generate Detailed Receipt PDF    ${order}[Order number]


*** Keywords ***
Process Orders Using Data From Orders File   
    ${orders}=    Read table from CSV    path=${CURDIR}${/}output${/}orders.csv    header=True
    FOR    ${order}    IN    @{orders}
        Log    ${order}
        Process One Order    ${order}
        Wait Until Element Is Visible    locator=id:order-another
        Click Button    locator=id:order-another
        Close Annoying Modal
    END

*** Keywords ***
Display Path Of Receipts File
    [Arguments]    ${file_path}
    ${text_message}=    CATENATE    Orders Zip File Location:    ${file_path}
    Add text    ${text_message}
    Show Dialog

*** Keywords ***
Archive All Receipts In Zip File
    Archive Folder With Zip
    ...    folder=${CURDIR}${/}output${/}
    ...    archive_name=${CURDIR}${/}output${/}order_receipts.zip
    ...    include=*receipt*.pdf
    Display Path Of Receipts File    ${CURDIR}${/}output${/}order_receipts.zip

*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    ${orders_file_url}=    Get Orders File From User
    ${build_a_robot_url}=    Get Build A Robot Url From Vault
    Download Orders File    ${orders_file_url}
    Open Intranet Website    ${build_a_robot_url}
    Close Annoying Modal
    Process Orders Using Data From Orders File
    Archive All Receipts In Zip File
    
    [Teardown]    Close Browser
