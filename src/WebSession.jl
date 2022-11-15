#= 

Developed by: Thiago Rodigues de Souza Simões.
Email: thiago.simoes@ufrj.br

JuliaWebSession is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.


Summary

Functions list:

- 'add_session'
- 'add_session_data'
- 'get_cookie'
- 'get_session'
- 'get_session_data'
- 'get_session_id'
- 'get_session_storage'
- 'id'
- 'remove_session'
- 'SessionStorageManagement'
- 'start_session'
- 'session_exists'

=#

module WebSession

export add_session, add_session_data, get_cookie, get_session, get_session_data,
get_session_id, get_session_storage, id, remove_session, SessionStorageManagement,
start_session, session_exists, Session

import SHA, HTTP, Dates, Logging, Random
import Genie

const SESSION_COOKIE_NAME::String = "JuliaSession"

const MAX_AGE::Int64 = 7200 # 2 hours

const SESSION_OPTIONS = Dict{Symbol,Any}(
    :path => "/",
    :httponly => true,
    :secure => (Genie.Configuration.isprod()),
    :samesite => HTTP.Cookies.SameSite(2),
    :maxage => MAX_AGE
)


struct Session
    id::String
    data::Dict{String, Any}
    date::Dates.DateTime
end

SessionStorage::Vector{Session} = Vector{Session}()

Session(id::String, data::Dict{String, Any} = Dict{String, Any}())::Session = Session(id, data, Dates.now())


# &&&&&&&&&&&&&&& Functions &&&&&&&&&&&&&&&


"""
    add_session(session::Session)::Nothing

Add a session to the session storage.

# Arguments
- `session`: the Session to be added.

# Returns
The function returns nothing.
"""
function add_session(session::Session)::Nothing
    push!(SessionStorage, session)
    nothing
end


"""
    add_session_data(
        key::String,
        value::Union{String, Real}, 
        req::HTTP.Request = Genie.Requests.request(),
        res::HTTP.Response = Genie.Responses.getresponse()
    )::Nothing

Add data to a session in the session storage.

# Arguments
- `key`: the key of the data to be added.
- `value`: the value of the data to be added.
- `req`: the HTTP.Request object.
- `res`: the HTTP.Response object.

# Return
The function returns nothing.
"""
function add_session_data(
    key::String,
    value::Union{String, Real}, 
    req::HTTP.Request = Genie.Requests.request(),
    res::HTTP.Response = Genie.Responses.getresponse()
)::Nothing
    id = get_session_id(req, res)
    if (id != nothing && get_session_storage(id) != nothing)
        SessionStorage[findfirst(s -> s.id == id, SessionStorage)].data[key] = value
    end
    nothing
end


"""
    get_cookie(
        payload::Union{HTTP.Request, HTTP.Response},
        name::String
    )::Union{HTTP.Cookie, Nothing}

Get a cookie from a HTTP.Request or HTTP.Response object.

# Arguments
- `payload`: the HTTP.Request or HTTP.Response object.
- `name`: the name of the cookie.

# Return
The function returns the cookie if it exists, otherwise it returns nothing.
"""
function get_cookie(
    payload::Union{HTTP.Request, HTTP.Response},
    name::String
)::Union{HTTP.Cookie, Nothing}
    cookies = HTTP.cookies(payload)
    cookie = [cookie for cookie in cookies if cookie.name == name]
    if length(cookie) == 1
        return cookie[1]
    end
    return nothing
end


"""
    get_session(
        req::HTTP.Request,
        res::HTTP.Response
    )::Union{Session, Nothing}

Get a session from the session storage for a HTTP.Request and HTTP.Response object.
If the session does not exist, it is created.

# Arguments
- `req`: the HTTP.Request object.
- `res`: the HTTP.Response object.

# Return
The function returns the session if it exists, otherwise it returns the newly created.
"""
function get_session(
    req::HTTP.Request,
    res::HTTP.Response
)::Session
    if (session_exists(req) || session_exists(res))
            
        session_id = get_session_id(req, res)
        session = [s for s in SessionStorage if s.id == session_id]
        @assert length(session) == 1 "Cannot have more than one session with the same id"
        
        if ((Dates.now() - session[1].date) > Dates.Second(MAX_AGE))
            remove_session(session_id)
            return start_session(req, res)
        end


        return session[1]
    end
    return start_session(req, res)
end


"""
    get_session_data(
        key::String,
        req::HTTP.Request = Genie.Requests.request(),
        res::HTTP.Response = Genie.Responses.getresponse()
    )::Union{Any, Nothing}

Gets the data for a session in the session store that matches the key.

# Arguments
- `key`: the key of the data to be retrieved.
- `req`: the HTTP.Request object. By default is Genie.Requests.request().
- `res`: the HTTP.Response object. By default is Genie.Responses.getresponse().

# Return
The function returns the data if it exists, otherwise it returns nothing.
"""
function get_session_data(
    key::String,
    req::HTTP.Request = Genie.Requests.request(),
    res::HTTP.Response = Genie.Responses.getresponse()
)::Union{Any, Nothing}
    session = get_session(req, res)
    if session !== nothing && !isempty(session.data)
        return session.data[key]
    end
    return nothing
end


"""
    get_session_id(req::HTTP.Request, res::HTTP.Response)::Union{String, Nothing}

Get the session id from a HTTP.Request or HTTP.Response object.
First will try to get the session id from the HTTP.Request object.
If it does not exist, it will try to get it from the HTTP.Response object.

# Arguments
- `req`: the HTTP.Request object.
- `res`: the HTTP.Response object.

# Return
The function returns the session id if it exists, otherwise it returns nothing.
"""
function get_session_id(req::HTTP.Request, res::HTTP.Response)::Union{String, Nothing}
    if session_exists(req)
        return get_cookie(req, SESSION_COOKIE_NAME).value
    elseif session_exists(res)
        return get_cookie(res, SESSION_COOKIE_NAME).value
    end
    return nothing
end


"""
    get_session_storage(session_id::String)::Union{Session, Nothing}

Get a session from the session storage for a session id.

# Arguments
- `session_id`: the session id.

# Return
The function returns the session if it exists, otherwise it returns nothing.
"""
function get_session_storage(session_id::String)::Union{Session, Nothing}
    for session in SessionStorage
        if session.id == session_id
            return session
        end
    end
    return nothing
end


"""
    id()::String

    Generates a random Session id.

# Return
The function returns a random string Session id.
"""
function id()::String
    bytes2hex(SHA.sha512(Random.randstring(Random.RandomDevice(), 512)))
end


"""
    remove_session(session_id::String)::Nothing

Remove a session from the session storage.

# Arguments
- `session_id`: the session id.

# Return
The function returns nothing.
"""
function remove_session(session_id::String)::Nothing
    names = [s.id for s in SessionStorage]
    index = findfirst((x -> x == session_id), names)
    deleteat!(SessionStorage, index)
    nothing  
end


"""
    session_exists(payload::Union{HTTP.Request, HTTP.Response})::Bool

Check if a session exists for a HTTP.Request or HTTP.Response object.

# Arguments
- `payload`: the HTTP.Request or HTTP.Response object.

# Return
The function returns true if the session exists, otherwise it returns false.
"""
function session_exists(payload::Union{HTTP.Request, HTTP.Response})::Bool
    cookie = get_cookie(payload, SESSION_COOKIE_NAME)
    if (cookie != nothing && cookie.value != "" && get_session_storage(cookie.value) != nothing)
        return true
    end
    return false
end


"""
    start_session(req::HTTP.Request, res::HTTP.Response)::Session

Starts a session to an HTTP.Request and HTTP.Response object.  
Checks if the session already exists and if it does, returns it.  
The cookie is set in the response. The session is added to the session store.  
    
# Arguments
- `req`: the HTTP.Request object.
- `res`: the HTTP.Response object.

# Return
The function returns the new session or an existing session.
"""
function start_session(req::HTTP.Request, res::HTTP.Response)::Session
    if !(session_exists(req) || session_exists(res))
        session_id = id()
        new_session_cookie = HTTP.Cookie(SESSION_COOKIE_NAME, session_id; SESSION_OPTIONS...)
        HTTP.Cookies.addcookie!(res, new_session_cookie)
        session = Session(session_id)
        add_session(session)
        return session
    end
    return get_session(req, res)
end


"""
    SessionStorageManagement()::Nothing

Manages the session storage. It's is a infinite loop that runs every 10 second.
It checks if the session has expired and if it has, it removes it from the session storage.
Don't need to call this function, it is called automatically by __init__() function and 
runs assyncronously.

# Return
The function returns nothing.
"""
function SessionStorageManagement()::Nothing
    while true
        sleep(10)
        if length(SessionStorage) != 0
            for session in SessionStorage
                if (Dates.now() - session.date) > Dates.Second(MAX_AGE)
                    remove_session(session.id)
                end
            end
        end
    end
end

function __init__()
    @async SessionStorageManagement()
end

end # module EasySession
