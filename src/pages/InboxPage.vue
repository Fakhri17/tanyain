<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '@/lib/supabase'
import { useToast } from '@/composables/useToast'

const toast = useToast()
const route = useRoute()
const username = route.params.username as string

interface Profile {
  id: string
  display_name: string
  bio: string
  is_public: boolean
}

const profile = ref<Profile | null>(null)
const notFound = ref(false)
const loadingPage = ref(true)

const questionText = ref('')
const honeypot = ref('')
const submitting = ref(false)
const submitted = ref(false)
const submitError = ref('')

const charCount = computed(() => questionText.value.length)
const charLeft = computed(() => 500 - charCount.value)

async function fetchProfile() {
  const { data, error } = await supabase
    .from('profiles')
    .select('id, display_name, bio, is_public')
    .eq('username', username)
    .single()

  if (error || !data || !data.is_public) {
    notFound.value = true
    return
  }

  profile.value = data
}

async function handleSubmit() {
  if (honeypot.value) return

  submitError.value = ''

  if (charCount.value < 5) {
    submitError.value = 'Pertanyaan minimal 5 karakter'
    return
  }
  if (charCount.value > 500) {
    submitError.value = 'Pertanyaan maksimal 500 karakter'
    return
  }

  submitting.value = true
  try {
    const { error } = await supabase.from('questions').insert({
      inbox_owner_id: profile.value!.id,
      body: questionText.value.trim(),
      status: 'pending',
    })

    if (error) throw error

    submitted.value = true
    questionText.value = ''
    toast.success('Pertanyaanmu terkirim!')
  } catch {
    submitError.value = 'Gagal mengirim pertanyaan. Coba lagi.'
    toast.error('Gagal mengirim pertanyaan.')
  } finally {
    submitting.value = false
  }
}

function resetForm() {
  submitted.value = false
  submitError.value = ''
}

onMounted(async () => {
  await fetchProfile()
  loadingPage.value = false
})
</script>

<template>
  <div class="min-h-screen bg-gray-50">
    <div class="max-w-2xl mx-auto px-4 py-10">

      <!-- Loading -->
      <div v-if="loadingPage" class="space-y-4">
        <div class="h-8 bg-gray-200 rounded w-1/3 animate-pulse"></div>
        <div class="h-4 bg-gray-200 rounded w-2/3 animate-pulse"></div>
      </div>

      <!-- Not Found -->
      <div v-else-if="notFound" class="text-center py-20">
        <p class="text-4xl font-bold text-gray-300 mb-2">404</p>
        <p class="text-gray-500">Halaman ini tidak ditemukan atau tidak publik.</p>
      </div>

      <template v-else-if="profile">
        <!-- Profile Header -->
        <div class="mb-8 text-center">
          <h1 class="text-2xl font-bold text-gray-900">{{ profile.display_name }}</h1>
          <p v-if="profile.bio" class="text-gray-500 mt-1">{{ profile.bio }}</p>
        </div>

        <!-- Question Form -->
        <div class="bg-white rounded-2xl shadow p-6">
          <h2 class="text-base font-semibold text-gray-800 mb-3">Kirim pertanyaan anonim</h2>

          <!-- Honeypot (hidden) -->
          <input
            v-model="honeypot"
            type="text"
            tabindex="-1"
            autocomplete="off"
            style="position:absolute;left:-9999px;width:1px;height:1px;opacity:0"
            aria-hidden="true"
          />

          <div v-if="submitted" class="text-center py-6">
            <p class="text-green-600 font-medium text-lg">Pertanyaanmu terkirim!</p>
            <p class="text-gray-400 text-sm mt-1">Identitasmu tetap anonim.</p>
            <button
              @click="resetForm"
              class="mt-4 text-sm text-indigo-600 hover:underline"
            >
              Kirim pertanyaan lain
            </button>
          </div>

          <form v-else @submit.prevent="handleSubmit">
            <textarea
              v-model="questionText"
              rows="4"
              placeholder="Tanya sesuatu..."
              maxlength="500"
              class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-indigo-500"
            ></textarea>

            <div class="flex items-center justify-between mt-2">
              <p
                class="text-xs"
                :class="charLeft < 20 ? 'text-red-500' : 'text-gray-400'"
              >
                {{ charCount }}/500
              </p>
              <p v-if="submitError" class="text-xs text-red-500">{{ submitError }}</p>
            </div>

            <button
              type="submit"
              :disabled="submitting || charCount < 5"
              class="mt-3 w-full bg-indigo-600 hover:bg-indigo-700 disabled:bg-indigo-300 text-white font-medium py-2 px-4 rounded-lg text-sm transition-colors"
            >
              {{ submitting ? 'Mengirim...' : 'Kirim' }}
            </button>
          </form>
        </div>
      </template>

    </div>
  </div>
</template>
