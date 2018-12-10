# Courriel

`Courriel` is a "_peer-to-peer messaging system_", i.e., it does not
require a central server.

Project `courriel` is split into two parts:

1.  __User Interface__: Graphical User Interface (in `html/css/js`) to
    be execuded in a browser.

2.  __Local Server__: A server usually running on a client device
    whose role is to keep in sync with peers. Its role is
    1. to initialize, maintain, and provide to the _user interface_
       the _state_ of the "mailboxes"
    2. to keep in sync with peers

### Project source files organization 

The project source files are in `src/`

      .
      ├── client/index.js  -  user interface code (via `browserify` -> `public/js/courriel.js`)
      ├── index.js    - local server code
      ├── peers.js    - communication/synchronisation between peers
      ├── node_modules/...
      ├── package.json  -  third party dependences 
      ├── public   -  files in `public/*` are served to the client "as is"
      │   ├── css/...
      │   ├── images/...
      │   └── js/...
      └── views/courriel.jade - `jade` template used to generate user interface `html`

### Run the app

Do:

    > git clone https://github.com/fraczak/courriel.git
    > cd courriel/src
    > npm install
    > npm run build
    > npm start

Then go to: http://localhost:8888/


# TODO

1. convert to coffee-script
2. use sql as a backend
3. stream the json 
4. salt the symetric key
