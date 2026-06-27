<script setup lang="ts">
import { onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuth } from '@/composables/useAuth'

const { isLoggedIn } = useAuth()
const router = useRouter()

onMounted(() => {
  if (isLoggedIn.value) router.replace('/dashboard')
})
</script>

<template>
  <div class="min-h-screen bg-gray-50 flex flex-col items-center justify-center px-4 text-center">
    <h1 class="text-4xl font-bold text-gray-900 mb-4">TanyaIn</h1>
    <p class="text-lg text-gray-500 max-w-md mb-8">
      Terima pertanyaan anonim dari siapa saja. Jawab yang kamu mau, sembunyikan yang tidak perlu.
      Tanpa akun, tanpa identitas penanya.
    </p>

    <div class="flex flex-col sm:flex-row gap-3">
      <RouterLink
        to="/register"
        class="bg-indigo-600 hover:bg-indigo-700 text-white font-semibold px-6 py-3 rounded-xl transition-colors"
      >
        Buat Inbox Kamu
      </RouterLink>
      <RouterLink
        to="/login"
        class="bg-white hover:bg-gray-100 text-gray-700 font-semibold px-6 py-3 rounded-xl border border-gray-300 transition-colors"
      >
        Sudah punya akun
      </RouterLink>
    </div>

    <p class="text-sm text-gray-400 mt-12">
      Gratis · Anonim · Tanpa spam
    </p>
  </div>
</template>
