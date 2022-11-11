module JuliaWebSession

import SHA, HTTP, Dates, Logging, Random
import Genie

const SESSION_COOKIE_NAME = "JuliaSession"

const MAX_AGE = 7200 # 2 hours

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

SessionStorage = Vector{Session}()

# Session(id::String)::Session = Session(id, Dict{String, Any}(), Dates.now())
Session(id::String, data::Dict{String, Any} = Dict{String, Any}())::Session = Session(id, data, Dates.now())

"""
    id()::String

    Generates a random Session id.

"""
function id()::String
    bytes2hex(SHA.sha512(Random.randstring(Random.RandomDevice(), 512)))
end


function start_session(req::HTTP.Request, res::HTTP.Response)::Session
    if !(_check_session_exist(req) || _check_session_exist(res))
        session_id = id()
        new_session_cookie = HTTP.Cookie(SESSION_COOKIE_NAME, session_id; SESSION_OPTIONS...)
        HTTP.Cookies.addcookie!(res, new_session_cookie)
        session = Session(session_id)
        add_session(session)
        return session
    end
    return get_session(req, res)
end

function add_session(session::Session)::Nothing
    push!(SessionStorage, session)
    nothing
end

function get_session_storage(session_id::String)::Union{Session, Nothing}
    for session in SessionStorage
        if session.id == session_id
            return session
        end
    end
    return nothing
end


function get_session(req::HTTP.Request, res::HTTP.Response)::Union{Session, Nothing}
    if (_check_session_exist(req) || _check_session_exist(res))
            
        session_id = get_session_id(req, res)
        session = [s for s in SessionStorage if s.id == session_id]
        @assert length(session) == 1 "Cannot have more than one session with the same id"
        
        println("Session: ", session)

        if ((Dates.now() - session[1].date) > Dates.Second(MAX_AGE))
            println("Session expired")
            _remove_session(session_id)
            return start_session(req, res)
        end

        println("Ok here ")

        return session[1]
    end
    return start_session(req, res)
end

function get_session_data(key::String, req::HTTP.Request = Genie.Requests.request(), res::HTTP.Response = Genie.Responses.getresponse())::Union{Any, Nothing}
    session = get_session(req, res)
    if session !== nothing && !isempty(session.data)
        println("\n\n")
        println(session.data)
        return session.data[key]
    end
    return nothing
end


function add_session_data(key::String, value::Union{String, Real}, req::HTTP.Request = Genie.Requests.request(), res::HTTP.Response = Genie.Responses.getresponse())::Nothing
    id = get_session_id(req, res)
    if (id != nothing && get_session_storage(id) != nothing)
        SessionStorage[findfirst(s -> s.id == id, SessionStorage)].data[key] = value
    end
    nothing
end


function _remove_session(session_id::String)
    names = [s.id for s in SessionStorage]
    index = findfirst((x -> x == session_id), names)
    deleteat!(SessionStorage, index)
    nothing  
end

function get_session_id(req::HTTP.Request, res::HTTP.Response)::String
    if _check_session_exist(req)
        return get_cookie(req, SESSION_COOKIE_NAME).value
    elseif _check_session_exist(res)
        return get_cookie(res, SESSION_COOKIE_NAME).value
    end
    return id()
end

function get_cookie(payload::Union{HTTP.Request, HTTP.Response}, name::String)::Union{HTTP.Cookie, Nothing}
    cookies = HTTP.cookies(payload)
    cookie = [cookie for cookie in cookies if cookie.name == name]
    if length(cookie) == 1
        return cookie[1]
    end
    return nothing
end

function _check_session_exist(payload::Union{HTTP.Request, HTTP.Response})
    cookie = get_cookie(payload, SESSION_COOKIE_NAME)
    if (cookie != nothing && cookie.value != "" && get_session_storage(cookie.value) != nothing)
        return true
    end
    return false
end


function SessionStorageManagement()
    while true
        sleep(1)
        if length(SessionStorage) != 0
            for session in SessionStorage
                if (Dates.now() - session.date) > Dates.Second(MAX_AGE)
                    _remove_session(session.id)
                end
            end
        end
    end
end

function __init__()
    @async SessionStorageManagement()
end

end # module EasySession
