<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'
import { useToast } from '@/composables/useToast'

const router = useRouter()
const { register } = useAuth()
const toast = useToast()

const email = ref('')
const password = ref('')
const username = ref('')
const displayName = ref('')
const error = ref('')
const loading = ref(false)

const errors = ref({
  email: '',
  password: '',
  username: '',
  displayName: '',
})

function validateEmail(val: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(val)
}

function validateUsername(val: string) {
  return /^[a-z0-9_]{3,20}$/.test(val)
}

function validate() {
  errors.value = { email: '', password: '', username: '', displayName: '' }
  let valid = true

  if (!validateEmail(email.value)) {
    errors.value.email = 'Email tidak valid'
    valid = false
  }
  if (password.value.length < 8) {
    errors.value.password = 'Password minimal 8 karakter'
    valid = false
  }
  if (!validateUsername(username.value)) {
    errors.value.username = 'Username: 3-20 karakter, hanya huruf kecil, angka, underscore'
    valid = false
  }
  if (!displayName.value.trim()) {
    errors.value.displayName = 'Display name tidak boleh kosong'
    valid = false
  }

  return valid
}

async function handleSubmit() {
  if (!validate()) return
  loading.value = true
  error.value = ''
  try {
    await register(email.value, password.value, username.value, displayName.value.trim())
    toast.success('Akun berhasil dibuat!')
    router.push('/dashboard')
  } catch (e: unknown) {
    error.value = e instanceof Error ? e.message : 'Terjadi kesalahan'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="min-h-screen flex items-center justify-center bg-gray-50 px-4">
    <div class="w-full max-w-md bg-white rounded-2xl shadow p-8">
      <h1 class="text-2xl font-bold text-gray-900 mb-6">Buat Akun</h1>

      <form @submit.prevent="handleSubmit" class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Display Name</label>
          <input
            v-model="displayName"
            type="text"
            placeholder="Nama yang ditampilkan"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
          <p v-if="errors.displayName" class="text-red-500 text-xs mt-1">{{ errors.displayName }}</p>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Username</label>
          <input
            v-model="username"
            type="text"
            placeholder="contoh: john_doe"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
          <p v-if="errors.username" class="text-red-500 text-xs mt-1">{{ errors.username }}</p>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Email</label>
          <input
            v-model="email"
            type="email"
            placeholder="kamu@email.com"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
          <p v-if="errors.email" class="text-red-500 text-xs mt-1">{{ errors.email }}</p>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-1">Password</label>
          <input
            v-model="password"
            type="password"
            placeholder="Minimal 8 karakter"
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
          />
          <p v-if="errors.password" class="text-red-500 text-xs mt-1">{{ errors.password }}</p>
        </div>

        <p v-if="error" class="text-red-600 text-sm bg-red-50 border border-red-200 rounded-lg px-3 py-2">
          {{ error }}
        </p>

        <button
          type="submit"
          :disabled="loading"
          class="w-full bg-indigo-600 hover:bg-indigo-700 disabled:bg-indigo-400 text-white font-medium py-2 px-4 rounded-lg text-sm transition-colors"
        >
          {{ loading ? 'Memproses...' : 'Daftar' }}
        </button>
      </form>

      <p class="text-sm text-gray-600 text-center mt-4">
        Sudah punya akun?
        <RouterLink to="/login" class="text-indigo-600 hover:underline">Masuk</RouterLink>
      </p>
    </div>
  </div>
</template>
