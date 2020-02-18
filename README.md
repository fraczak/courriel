# Courriel

`Courriel` is a "_peer-to-peer messaging system_", i.e., it does not
require a central server.

Project `courriel` is split into two parts:

1. __User Interface__: Graphical User Interface (in `html/css/js`, or rather `jade/css/coffee`)
    to be execuded in a browser.

2. __Local Server__: A server usually running on a client device
    whose role is to keep in sync with peers.  Its role is
    1. to initialize, maintain, and provide to the _user interface_
       the data
    2. to keep in sync with peers

## Project source files organization

The project source files are in `src/`

      .
      ├── client/index.coffee - user interface code (via `browserify` -> `public/js/courriel.js`)
      ├── index.coffee        - local server code
      ├── Peers.coffee        - communication/synchronisation between peers
      ├── Etat.coffee         - database initilization and api 
      ├── node_modules/...    - dependences
      ├── package.json        - project file
      ├── public              - files in `public/*` are served to the client "as is"
      │   ├── style.css
      │   ├── favicon.ico
      │   ├── css/...         - generated with `npm run jquery-ui-css`
      │   └── js/...          - generated with `npm run build`
      └── views/courriel.jade - `jade` template used to generate user interface `html`

### Run the app

Do:

    > git clone https://github.com/fraczak/courriel.git
    > cd courriel
    > npm install
    > npm run jquery-ui-css
    > npm run build
    > npm start

Then go to: http://localhost:8888/

