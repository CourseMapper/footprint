FootPrint
=========

<img width="250" alt="screen shot 2015-11-23 at 10 27 10 am" src="https://cloud.githubusercontent.com/assets/1277720/11333275/c9013286-91cc-11e5-81b4-bf0ca81b51ce.png">


RWTH Aachen University - Master thesis

## Installation

Pre-requisities:

1. MongoDB
2. NodeJS
3. npm
 
**Install and run MongoDB**

https://docs.mongodb.org/manual/installation/

For Mac OS:
```
brew install mongodb
mkdir -p /data/db
sudo mongod
```

**Install command line tools**
```
npm install -g gulp
npm install -g bower
npm install -g coffee-script
```
**Install dependencies**
```
npm install
bower install
```

**Run pre-script compiler**
```
gulp build
```

**Run the application**
```
gulp
```

Now you can use the FootPrint

http://localhost:8080/get

### Production

Open `app.coffee` file and change port:

```coffee
app.listen 80
```

**Install pm2**
```
npm install -g pm2
```

**Run application**
```
pm2 start app.coffee
```


### Run examples

- Install and run Apache
- Setup a virtual host, directory should reffer to the `demo` folder
