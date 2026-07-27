use blst::min_pk::{AggregateSignature, PublicKey, SecretKey, Signature};
use blst::{
    BLST_ERROR, blst_fp12, blst_p1_affine, blst_p1_generator, blst_p1_to_affine, blst_p2,
    blst_p2_affine, blst_p2_from_affine, blst_p2_mult, blst_p2_to_affine, blst_scalar,
    blst_scalar_from_bendian, blst_sk_inverse,
};
use rustler::{Binary, Encoder, Env, NifResult, OwnedBinary, Term};

const SIGNATURE_DST: &[u8] = b"PHI_CRYPTO_BLS12_381_PROOF_V1";

fn error<'a>(env: Env<'a>, reason: &str) -> Term<'a> {
    (rustler::types::atom::error(), reason).encode(env)
}

fn ok_binary<'a>(env: Env<'a>, bytes: &[u8]) -> NifResult<Term<'a>> {
    let mut binary = OwnedBinary::new(bytes.len()).ok_or(rustler::Error::Term(Box::new(
        "could not allocate signature binary",
    )))?;
    binary.as_mut_slice().copy_from_slice(bytes);
    Ok((rustler::types::atom::ok(), binary.release(env)).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn sign<'a>(env: Env<'a>, private_key: Binary<'a>, message: Binary<'a>) -> NifResult<Term<'a>> {
    match SecretKey::from_bytes(private_key.as_slice()) {
        Ok(secret_key) => {
            let signature = secret_key.sign(message.as_slice(), SIGNATURE_DST, &[]);
            ok_binary(env, &signature.compress())
        }
        Err(_) => Ok(error(env, "invalid BLS12-381 private key")),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn base<'a>(env: Env<'a>, message: Binary<'a>) -> NifResult<Term<'a>> {
    let mut scalar = [0u8; 32];
    scalar[31] = 1;

    match SecretKey::from_bytes(&scalar) {
        Ok(one) => ok_binary(
            env,
            &one.sign(message.as_slice(), SIGNATURE_DST, &[]).compress(),
        ),
        Err(_) => Ok(error(env, "could not initialize BLS12-381 accumulator")),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn scale<'a>(env: Env<'a>, point: Binary<'a>, private_key: Binary<'a>) -> NifResult<Term<'a>> {
    match (
        Signature::sig_validate(point.as_slice(), true),
        SecretKey::from_bytes(private_key.as_slice()),
    ) {
        (Ok(point), Ok(secret_key)) => {
            let point_affine: blst_p2_affine = point.into();
            let mut point_projective = blst_p2::default();
            let mut scaled_projective = blst_p2::default();
            let mut scaled_affine = blst_p2_affine::default();
            let scalar_bytes = secret_key.to_bytes();
            let mut scalar = blst_scalar::default();

            unsafe {
                blst_scalar_from_bendian(&mut scalar, scalar_bytes.as_ptr());
                blst_p2_from_affine(&mut point_projective, &point_affine);
                blst_p2_mult(
                    &mut scaled_projective,
                    &point_projective,
                    scalar.b.as_ptr(),
                    255,
                );
                blst_p2_to_affine(&mut scaled_affine, &scaled_projective);
            }

            ok_binary(env, &Signature::from(scaled_affine).compress())
        }
        (Err(_), _) => Ok(error(env, "invalid BLS12-381 accumulator point")),
        (_, Err(_)) => Ok(error(env, "invalid BLS12-381 private key")),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn unscale<'a>(env: Env<'a>, point: Binary<'a>, private_key: Binary<'a>) -> NifResult<Term<'a>> {
    match (
        Signature::sig_validate(point.as_slice(), true),
        SecretKey::from_bytes(private_key.as_slice()),
    ) {
        (Ok(point), Ok(secret_key)) => {
            let point_affine: blst_p2_affine = point.into();
            let mut point_projective = blst_p2::default();
            let mut unscaled_projective = blst_p2::default();
            let mut unscaled_affine = blst_p2_affine::default();
            let scalar_bytes = secret_key.to_bytes();
            let mut scalar = blst_scalar::default();
            let mut inverse = blst_scalar::default();

            unsafe {
                blst_scalar_from_bendian(&mut scalar, scalar_bytes.as_ptr());
                blst_sk_inverse(&mut inverse, &scalar);
                blst_p2_from_affine(&mut point_projective, &point_affine);
                blst_p2_mult(
                    &mut unscaled_projective,
                    &point_projective,
                    inverse.b.as_ptr(),
                    255,
                );
                blst_p2_to_affine(&mut unscaled_affine, &unscaled_projective);
            }

            ok_binary(env, &Signature::from(unscaled_affine).compress())
        }
        (Err(_), _) => Ok(error(env, "invalid BLS12-381 accumulator point")),
        (_, Err(_)) => Ok(error(env, "invalid BLS12-381 private key")),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn verify_transition<'a>(
    env: Env<'a>,
    previous: Binary<'a>,
    next: Binary<'a>,
    public_key: Binary<'a>,
) -> NifResult<Term<'a>> {
    let valid = match (
        Signature::sig_validate(previous.as_slice(), true),
        Signature::sig_validate(next.as_slice(), true),
        PublicKey::key_validate(public_key.as_slice()),
    ) {
        (Ok(previous), Ok(next), Ok(public_key)) => {
            let previous_affine: blst_p2_affine = previous.into();
            let next_affine: blst_p2_affine = next.into();
            let public_key_affine: blst_p1_affine = public_key.into();
            let mut generator_affine = blst_p1_affine::default();

            unsafe {
                blst_p1_to_affine(&mut generator_affine, blst_p1_generator());
            }

            let candidate_pairing = blst_fp12::miller_loop(&previous_affine, &public_key_affine);
            let transition_pairing = blst_fp12::miller_loop(&next_affine, &generator_affine);

            blst_fp12::finalverify(&candidate_pairing, &transition_pairing)
        }
        _ => false,
    };

    Ok(valid.encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn aggregate<'a>(env: Env<'a>, signatures: Vec<Binary<'a>>) -> NifResult<Term<'a>> {
    let parsed: Result<Vec<Signature>, BLST_ERROR> = signatures
        .iter()
        .map(|signature| Signature::uncompress(signature.as_slice()))
        .collect();

    match parsed {
        Ok(parsed) if !parsed.is_empty() => {
            let signature_refs: Vec<&Signature> = parsed.iter().collect();

            match AggregateSignature::aggregate(&signature_refs, true) {
                Ok(aggregate) => ok_binary(env, &aggregate.to_signature().compress()),
                Err(_) => Ok(error(env, "could not aggregate BLS12-381 signatures")),
            }
        }
        Ok(_) => Ok(error(env, "at least one BLS12-381 signature is required")),
        Err(_) => Ok(error(env, "invalid BLS12-381 signature")),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn verify<'a>(
    env: Env<'a>,
    public_keys: Vec<Binary<'a>>,
    message: Binary<'a>,
    signature: Binary<'a>,
) -> NifResult<Term<'a>> {
    let parsed_public_keys: Result<Vec<PublicKey>, BLST_ERROR> = public_keys
        .iter()
        .map(|public_key| PublicKey::uncompress(public_key.as_slice()))
        .collect();

    let valid = match (
        parsed_public_keys,
        Signature::uncompress(signature.as_slice()),
    ) {
        (Ok(public_keys), Ok(signature)) if !public_keys.is_empty() => {
            let public_key_refs: Vec<&PublicKey> = public_keys.iter().collect();
            signature.fast_aggregate_verify(
                true,
                message.as_slice(),
                SIGNATURE_DST,
                &public_key_refs,
            ) == BLST_ERROR::BLST_SUCCESS
        }
        _ => false,
    };

    Ok(valid.encode(env))
}

rustler::init!("Elixir.BorutaAuth.BlsSignature");
