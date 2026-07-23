package com.lasercyber.lws.frostui.card

/** Optional blur-radius / environment hooks supplied by the app layer. */
fun interface FrostEnvironment {
    fun defaultBlurRadiusPx(): Float
}

object FrostEnvironmentRegistry {
    @Volatile
    private var environment: FrostEnvironment? = null

    @JvmStatic
    fun register(environment: FrostEnvironment) {
        this.environment = environment
    }

    internal fun defaultBlurRadiusPx(): Float =
        environment?.defaultBlurRadiusPx() ?: 20f
}
