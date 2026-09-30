static char *fix_shadertoy_compatibility(const char *source) {
    return shadertoy_compat_fix(source);
}

/* Wrap a pass source with Shadertoy compatibility layer + neowall std-lib.
 * Layout: #version/uniforms (prefix) -> reactive uniforms -> GLSL std-lib ->
 * friendly aliases -> user common -> user pass -> main() suffix. The reactive
 * block and std-lib are injected unconditionally; unused uniforms/functions are
 * stripped by the GLSL compiler, so plain Shadertoy shaders are unaffected.
 *
 * The alias block is the one conditional part. Every canonical std-lib symbol
 * is nw*-prefixed and so can never collide, but the friendly unprefixed names
 * (sdBox, pulse, beat, ...) live in the same namespace the shader author does.
 * Emitting one the shader also defines is a hard GLSL error ("function `sdBox'
 * redefined", issue #82), so we scan the user's source first and withhold any
 * alias whose name is already taken. Shader wins; nw* stays available. */
static char *wrap_pass_source(const char *common, const char *pass_source,
                              const char *user_uniform_decls) {
    /* Which friendly aliases can we safely emit? Scan both the Common block and
     * the pass body: in GLSL they are concatenated into one translation unit,
     * so a name defined in either shadows the alias for both. A scan failure is
     * only ever OOM; treat it as "everything is taken" and emit no aliases,
     * which is the conservative direction (a missing alias is a clear
     * "undeclared function" the author can fix, whereas a wrong alias is the
     * redefinition crash we are eliminating). */
    glsl_shadow_set *shadow = glsl_shadow_create();
    bool shadow_ok = shadow != NULL;
    if (shadow_ok) {
        shadow_ok = glsl_shadow_scan(shadow, common) &&
                    glsl_shadow_scan(shadow, pass_source);
    }

    size_t alias_len = 0;
    bool emit_alias[NEOWALL_STDLIB_ALIAS_COUNT];
    for (size_t i = 0; i < NEOWALL_STDLIB_ALIAS_COUNT; i++) {
        emit_alias[i] = shadow_ok &&
                        !glsl_shadow_contains(shadow, neowall_stdlib_aliases[i].name);
        if (emit_alias[i]) alias_len += strlen(neowall_stdlib_aliases[i].decl);
    }

    size_t prefix_len = strlen(multipass_wrapper_prefix);
    size_t react_len  = strlen(neowall_reactive_uniforms);
    size_t lib_len    = strlen(neowall_glsl_stdlib) + strlen(neowall_glsl_stdlib2) + strlen(neowall_glsl_stdlib3) + strlen(neowall_glsl_stdlib4) + strlen(neowall_glsl_stdlib5) + strlen(neowall_glsl_stdlib6) + strlen(neowall_glsl_stdlib7);
    size_t udecl_len  = user_uniform_decls ? strlen(user_uniform_decls) : 0;
    size_t common_len = common ? strlen(common) : 0;
    size_t pass_len = pass_source ? strlen(pass_source) : 0;
    size_t suffix_len = strlen(multipass_wrapper_suffix);

    /* Extra space for .xy additions (worst case: every iChannelResolution gets .xy) */
    size_t total = prefix_len + react_len + lib_len + alias_len + udecl_len +
                   (common_len * 2) + (pass_len * 2) + suffix_len + 64;
    char *wrapped = malloc(total);
    if (!wrapped) {
        glsl_shadow_free(shadow);
        return NULL;
    }

    wrapped[0] = '\0';
    strcat(wrapped, multipass_wrapper_prefix);
    strcat(wrapped, neowall_reactive_uniforms);
    strcat(wrapped, neowall_glsl_stdlib);
    strcat(wrapped, neowall_glsl_stdlib2);
    strcat(wrapped, neowall_glsl_stdlib3);
    strcat(wrapped, neowall_glsl_stdlib4);
    strcat(wrapped, neowall_glsl_stdlib5);
    strcat(wrapped, neowall_glsl_stdlib6);
    strcat(wrapped, neowall_glsl_stdlib7);

    for (size_t i = 0; i < NEOWALL_STDLIB_ALIAS_COUNT; i++) {
        if (emit_alias[i]) strcat(wrapped, neowall_stdlib_aliases[i].decl);
    }
    glsl_shadow_free(shadow);

    if (user_uniform_decls) {
        strcat(wrapped, user_uniform_decls);
    }
    
    /* Apply compatibility fixes to common code. A #line 1 directive resets the
     * compiler's line counter so any error the driver reports points at the
     * user's own source line, not an offset into the injected preamble. */
    if (common) {
        strcat(wrapped, "#line 1\n");
        char *fixed_common = fix_shadertoy_compatibility(common);
        if (fixed_common) {
            strcat(wrapped, fixed_common);
            free(fixed_common);
        } else {
            strcat(wrapped, common);
        }
    }
    strcat(wrapped, "\n");

    /* Apply compatibility fixes to pass source. Reset line numbering again so a
     * single-file shader's errors read as "line N" of that file. */
    if (pass_source) {
        strcat(wrapped, "#line 1\n");
        char *fixed_pass = fix_shadertoy_compatibility(pass_source);
        if (fixed_pass) {
            strcat(wrapped, fixed_pass);
            free(fixed_pass);
        } else {
            strcat(wrapped, pass_source);
        }
    }
    strcat(wrapped, multipass_wrapper_suffix);

    return wrapped;
}
