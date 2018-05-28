# mockbetter

## getting started

### 1. run a container

  `docker run --rm -p 1080:1080 -itd skotchpine/mockbetter`

### 2. mock a route

  `curl -XPUT -d'{"method":"GET","path":"/how-do","code":"200","body":{"mock":"better"}}' localhost:1080/mock/routes/x/how-do`

### 3. verify behavior

  `curl localhost:1080/x/how-do`

### 4. view request history

  `curl localhost:1080/mock/history/x`

## all endpoints

### 1. get config

  `curl localhost:1080/mock/conf`

### 2. update config

  `curl -XPUT -d'{"default":{"code":"404"}}' localhost:1080/mock/conf`

### 3. reset everything

  `curl -XPUT localhost:1080/mock/reset`

### 4. create mock route for tenant

  `curl -XPUT -d'{"path":"/mock","method":"GET","body":"better","code":"200"}' localhost:1080/mock/routes/x`

### 5. reset all mock routes for tenant

  `curl -XDELETE localhost:1080/mock/routes/x`

### 6. get history for tenant

  `curl -XPUT localhost:1080/mock/history/x`

### 7. reset all history for tenant

  `curl -XDELETE localhost:1080/mock/history/x`

## default response modes

### 1. dump

`curl -XPUT -d'{"default":{"mode":"dump"}' localhost:1080`

`curl -d'{"say": "hello"}' localhost:1080`

`200 => { "method": "GET", "path": "/" }`

### 2. echo

`curl -XPUT -d'{"default":{"mode":"echo"}' localhost:1080`

`curl -d'{"say": "hello"}' localhost:1080`

`200 => { "say": "hello" }`

### 3. mock

`curl -XPUT -d'{"default":{"mode":"mock","status":"400"}' localhost:1080`

`curl -d'{"say": "hello"}' localhost:1080`

`400 => { "message": "mock better" }`

## development

`git clone https://github.com/skotchpine/mockbetter`

`cd mockbetter`

`bundle install`

`./test`
