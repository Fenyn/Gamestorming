class_name Identity
extends RefCounted
## Who this install is to the duel server: an RSA key pair made on first use and kept in
## `user://identity.key` (`--dev-scratch=<dir>` moves it to `<dir>/identity.key`). The private half
## never leaves this object: it is not sent, logged or put in a record. The server learns the public
## half from the greeting's ticket and checks that this copy holds the private one with a signature
## over a nonce of its own (`Net`). The id is the SHA-256 of the public key as PEM, 64 hex
## characters, and is what records and ratings key on. A reinstall or a lost file is a new identity.

const FILE: String = "user://identity.key"
const KEY_BITS: int = 2048
## A 2048-bit public key as PEM is about 450 characters.
const PUBLIC_PEM_MAX: int = 800
const SIGNATURE_MAX: int = 1024
## Characters of the id a log line shows.
const SHORT: int = 12
## Tests point this at a file of their own.
static var path_override: String = ""

var _key: CryptoKey = null
var _public: String = ""
var _id: String = ""


static func path() -> String:
	if path_override != "":
		return path_override
	for arg in DevArgs.user_args():
		if arg.begins_with("--dev-scratch="):
			return arg.substr("--dev-scratch=".length()).path_join("identity.key")
	return FILE


## A new identity in memory, not stored anywhere.
static func generate() -> Identity:
	var out: Identity = Identity.new()
	out._take(Crypto.new().generate_rsa(KEY_BITS))
	return out


## The identity stored at `file`, or a new one stored there. A key file that is there but cannot be
## read or parsed is renamed aside first, never overwritten; one that cannot be moved either leaves
## this run on a new identity that is not saved. Every new identity says so in the log.
static func load_or_make(file: String = path()) -> Identity:
	if FileAccess.file_exists(file):
		var stored: Identity = _read(file)
		if stored != null:
			return stored
		var aside: String = "%s.bad-%d" % [file, int(Time.get_unix_time_from_system())]
		var moved: Error = DirAccess.rename_absolute(file, aside)
		if moved != OK:
			var unsaved: Identity = generate()
			push_warning("identity: %s cannot be read or moved aside (%s), so this run uses a new identity %s that is not saved" % [file, error_string(moved), unsaved.short_id()])
			return unsaved
		push_warning("identity: %s could not be read and is now %s" % [file, aside.get_file()])
	var made: Identity = generate()
	var problem: String = made._write(file)
	if problem != "":
		push_warning("identity: made a new identity %s but could not save it to %s (%s), so it lasts for this run only" % [made.short_id(), file, problem])
	else:
		print("identity: made a new identity %s in %s" % [made.short_id(), file])
	return made


static func _read(file: String) -> Identity:
	var text: String = FileAccess.get_file_as_bytes(file).get_string_from_ascii()
	if not text.begins_with("-----BEGIN") or not text.contains("PRIVATE KEY-----"):
		return null
	var key: CryptoKey = CryptoKey.new()
	if key.load_from_string(text) != OK or key.is_public_only():
		return null
	var out: Identity = Identity.new()
	out._take(key)
	return out


func _take(key: CryptoKey) -> void:
	_key = key
	_public = key.save_to_string(true)
	_id = _public.sha256_text()


func _write(file: String) -> String:
	var dir: String = file.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var made: Error = DirAccess.make_dir_recursive_absolute(dir)
		if made != OK:
			return error_string(made)
	var out: FileAccess = FileAccess.open(file, FileAccess.WRITE)
	if out == null:
		return error_string(FileAccess.get_open_error())
	var stored: bool = out.store_string(_key.save_to_string(false))
	out.close()
	# Owner only where the system has Unix modes; on Windows the user profile's own access rules apply.
	FileAccess.set_unix_permissions(file, FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER)
	return "" if stored else "the write did not complete"


func public_pem() -> String:
	return _public


func id() -> String:
	return _id


func short_id() -> String:
	return short(_id)


static func short(identity_id: String) -> String:
	return identity_id.left(SHORT)


## RSA PKCS#1 v1.5 over the SHA-256 of `bytes`.
func sign(bytes: PackedByteArray) -> PackedByteArray:
	return Crypto.new().sign(HashingContext.HASH_SHA256, _digest(bytes), _key)


## Whether `sig` is the signature of `bytes` by the key `public_pem` names.
static func verify(public_pem: String, bytes: PackedByteArray, sig: PackedByteArray) -> bool:
	if sig.is_empty() or sig.size() > SIGNATURE_MAX:
		return false
	var key: CryptoKey = _public_key(public_pem)
	return key != null and Crypto.new().verify(HashingContext.HASH_SHA256, _digest(bytes), sig, key)


## `public_pem` written out again the one way this class writes a public key, so one key has one id
## however its PEM was spaced; "" for anything that is not a public key.
static func canonical_public(public_pem: String) -> String:
	var key: CryptoKey = _public_key(public_pem)
	return key.save_to_string(true) if key != null else ""


## The id of the key `public_pem` names, "" for anything that is not a public key.
static func id_of(public_pem: String) -> String:
	var canonical: String = canonical_public(public_pem)
	return canonical.sha256_text() if canonical != "" else ""


static func _public_key(public_pem: String) -> CryptoKey:
	if public_pem.length() > PUBLIC_PEM_MAX or not public_pem.begins_with("-----BEGIN PUBLIC KEY-----"):
		return null
	var key: CryptoKey = CryptoKey.new()
	return key if key.load_from_string(public_pem, true) == OK else null


static func _digest(bytes: PackedByteArray) -> PackedByteArray:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish()
