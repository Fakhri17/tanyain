<script setup lang="ts">
import { useAuth } from '@/composables/useAuth'
import { useRouter } from 'vue-router'
import { useToast } from '@/composables/useToast'

const { isLoggedIn, logout } = useAuth()
const router = useRouter()
const toast = useToast()

async function handleLogout() {
  try {
    await logout()
    router.push('/')
    toast.success('Berhasil keluar')
  } catch {
    toast.error('Gagal keluar. Coba lagi.')
  }
}
</script>

<template>
  <header class="bg-white border-b border-gray-200 px-4 py-3">
    <div class="max-w-3xl mx-auto flex items-center justify-between">
      <RouterLink to="/" class="font-bold text-indigo-600 text-lg">TanyaIn</RouterLink>

      <nav class="flex items-center gap-3">
        <template v-if="isLoggedIn">
          <RouterLink
            to="/dashboard"
            class="text-sm text-gray-600 hover:text-gray-900 font-medium"
          >
            Dashboard
          </RouterLink>
          <button
            @click="handleLogout"
            class="text-sm text-gray-400 hover:text-red-500 transition-colors"
          >
            Keluar
          </button>
        </template>

        <template v-else>
          <RouterLink
            to="/login"
            class="text-sm text-gray-600 hover:text-gray-900 font-medium"
          >
            Masuk
          </RouterLink>
          <RouterLink
            to="/register"
            class="text-sm bg-indigo-600 hover:bg-indigo-700 text-white font-medium px-4 py-1.5 rounded-lg transition-colors"
          >
            Daftar
          </RouterLink>
        </template>
      </nav>
    </div>
  </header>
</template>
