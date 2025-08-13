# AI-assistant script
Simple script for linux to interact with ai-assistant by global hot-key.

## Getting Started

1. Copy the files to any folder.
2. Edit the .config file and add your OpenAI or DeepSeek token. You can also change the model if you wish.
3. Set a global hotkey to launch the script file. In Ubuntu, you do this through Settings -> Keyboard -> View and Customize hotkeys -> Custom hotkeys.

## How to Use

### The script works like this:
When you run the script, it first checks for any highlighted text or content in your clipboard. If found, this text is used as context. A Zenity window will then appear with this text already inserted. If the clipboard is empty and no text is selected, the window will be blank.

You can then add your prompt to the context and send the request to the AI by clicking the "Send" button. A loading indicator will be shown while the AI processes your request. The AI's response will be displayed in a new Zenity window.

## Dependencies

### To run this Bash script, you need the following dependencies:

    *zenity*: A tool for creating graphical dialog boxes from the command line. The script uses it for both the input and output windows.
    *curl*: A command-line utility for interacting with web servers, used to send HTTP requests to the API.
    *jq*: A command-line JSON processor, used to parse and extract data from the API's JSON response.
    *notify-send*: A tool for sending desktop notifications, used to display system messages (errors, status updates).
    *xclip*: A utility to access the clipboard, used to get selected text or clipboard content.

### How to Install Dependencies

For Debian/Ubuntu-based systems, you can install them with a single command:

    Bash
    sudo apt install zenity curl jq libnotify-bin xclip
