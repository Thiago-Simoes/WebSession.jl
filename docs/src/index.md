# Documentation

```@contents
```

## Sessions
```@docs
add_session(session::Session)
```
```@docs
add_session_data(
    key::String,
    value::Union{String, Real}, 
    req::HTTP.Request = Genie.Requests.request(),
    res::HTTP.Response = Genie.Responses.getresponse()
)
```
```@docs
get_cookie(
        payload::Union{HTTP.Request, HTTP.Response},
        name::String
)
```
```@docs
get_session(
        req::HTTP.Request,
        res::HTTP.Response
    )
```
```@docs
get_session_data(
        key::String,
        req::HTTP.Request = Genie.Requests.request(),
        res::HTTP.Response = Genie.Responses.getresponse()
)
```
```@docs
get_session_id(req::HTTP.Request, res::HTTP.Response)
```
```@docs
get_session_storage(session_id::String)
```
```@docs
id()
```
```@docs
remove_session(session_id::String)
```
```@docs
session_exists(payload::Union{HTTP.Request, HTTP.Response})
```
```@docs
start_session(req::HTTP.Request, res::HTTP.Response)
```
## Session Storage Management
```@docs
SessionStorageManagement()
```