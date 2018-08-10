
use "collections"
use "crdt"
use "resp"
use "time"

primitive RepoSYSTEMHelp is HelpLeaf
  fun apply(cmd: Iterator[String]): String =>
    """
    The following are valid SYSTEM commands:
      SYSTEM GETLOG [count]
      SYSTEM FORGETALL
    """

class RepoSYSTEM
  let _identity: U64
  var _database: (Database | None) = None
  
  let _log:       TLog[String] = TLog[String]
  var _log_delta: TLog[String] = TLog[String]
  
  new create(identity': U64) => _identity = identity'
  fun ref setup(database': Database) => _database = database'
  
  fun ref delta_empty(): Bool => _log_delta.is_empty()
  fun ref flush_deltas(): Tokens =>
    // TODO: allow for other fields besides just log.
    Tokens .> from(_log_delta = _log_delta.create())
  
  fun ref data_tokens(): Tokens =>
    Tokens .> from(_log)
  
  fun ref history_tokens(): Tokens =>
    Tokens .> push(USize(0)) // TODO
  
  fun ref converge(tokens: TokensIterator)? =>
    // TODO: allow for other fields besides just log.
    _log.converge(_log_delta.create() .> from_tokens(tokens)?)
  
  fun ref compare_history(tokens: TokensIterator): (Bool, Bool) =>
    (false, false) // TODO
  
  fun ref apply(r: Respond, cmd: Iterator[String]): Bool? =>
    match cmd.next()?
    | "GETLOG"    => getlog(r, _optcount(cmd))
    | "FORGETALL" => forgetall(r)
    else error
    end
  
  fun tag _optcount(cmd: Iterator[String]): USize =>
    try cmd.next()?.usize()? else -1 end
  
  fun ref _time_now_millis(): U64 =>
    (let secs, let nano) = Time.now()
    (secs.u64() * 1000) + (nano.u64() / 1000000)
  
  fun ref getlog(resp: Respond, count: USize): Bool =>
    var total = _log.size().min(count)
    resp.array_start(total)
    for (value, timestamp) in _log.entries() do
      if 0 == (total = total - 1) then break end
      resp.array_start(2)
      resp.string(value)
      resp.u64(timestamp)
    end
    false
  
  fun forgetall(resp: Respond): Bool =>
    try (_database as Database).forget_all() end
    resp.ok()
    false
  
  ///
  // System private methods, meant for use only within the jylis server.
  // Generally, the purpose is to fill data that is read-only to the user.
  
  fun ref _inslog(value: String) =>
    _log.write(value, _time_now_millis(), _log_delta)
  
  fun ref _trimlog(count: USize) =>
    _log.trim(count)
