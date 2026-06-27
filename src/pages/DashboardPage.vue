<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, watch } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/composables/useAuth'
import { useToast } from '@/composables/useToast'

const { user } = useAuth()
const toast = useToast()

// ── Types ──────────────────────────────────────────────────────────────────

interface Answer {
  id: string
  body: string
  answered_at: string
}

interface Question {
  id: string
  body: string
  status: 'pending' | 'answered' | 'hidden'
  submitted_at: string
  answer: Answer | null
}

interface Profile {
  id: string
  username: string
  display_name: string
  bio: string
  is_public: boolean
}

// ── State ──────────────────────────────────────────────────────────────────

const activeTab = ref<'questions' | 'settings'>('questions')
const filterTab = ref<'all' | 'pending' | 'answered'>('all')

const questions = ref<Question[]>([])
const profile = ref<Profile | null>(null)
const loadingQuestions = ref(true)
const loadingProfile = ref(true)

// Answer form per question
const answerDraft = ref<Record<string, string>>({})
const answeringId = ref<string | null>(null)
const submittingAnswer = ref(false)

// Profile form
const profileForm = ref({ display_name: '', bio: '', is_public: true })
const savingProfile = ref(false)
const profileSaved = ref(false)
const profileError = ref('')
const copied = ref(false)

const hasNewQuestion = ref(false)

let realtimeChannel: ReturnType<typeof supabase.channel> | null = null

// ── Computed ───────────────────────────────────────────────────────────────

const filteredQuestions = computed(() => {
  if (filterTab.value === 'all') return questions.value
  if (filterTab.value === 'pending') return questions.value.filter(q => q.status === 'pending')
  return questions.value.filter(q => q.status === 'answered')
})

const inboxLink = computed(() => {
  if (!profile.value) return ''
  return `${window.location.origin}/inbox/${profile.value.username}`
})

// ── Data fetching ──────────────────────────────────────────────────────────

async function fetchQuestions() {
  if (!user.value) return
  loadingQuestions.value = true
  const { data } = await supabase
    .from('questions')
    .select('id, body, status, submitted_at, answers(id, body, answered_at)')
    .eq('inbox_owner_id', user.value.id)
    .order('submitted_at', { ascending: false })

  questions.value = ((data as any[]) ?? []).map((q) => ({
    id: q.id,
    body: q.body,
    status: q.status,
    submitted_at: q.submitted_at,
    // Supabase mengembalikan `answers` sebagai objek (relasi one-to-one karena
    // question_id unique) atau array — normalisasi ke satu objek / null.
    answer: Array.isArray(q.answers) ? (q.answers[0] ?? null) : (q.answers ?? null),
  }))
  loadingQuestions.value = false
}

async function fetchProfile() {
  if (!user.value) return
  loadingProfile.value = true
  const { data } = await supabase
    .from('profiles')
    .select('id, username, display_name, bio, is_public')
    .eq('id', user.value.id)
    .single()

  if (data) {
    profile.value = data
    profileForm.value = {
      display_name: data.display_name,
      bio: data.bio,
      is_public: data.is_public,
    }
  }
  loadingProfile.value = false
}

// ── Actions ────────────────────────────────────────────────────────────────

function toggleAnswerForm(id: string) {
  answeringId.value = answeringId.value === id ? null : id
  if (!answerDraft.value[id]) answerDraft.value[id] = ''
}

async function submitAnswer(question: Question) {
  const body = answerDraft.value[question.id]?.trim()
  if (!body) return

  submittingAnswer.value = true
  try {
    const { error: insertErr } = await supabase
      .from('answers')
      .insert({ question_id: question.id, body })

    if (insertErr) throw insertErr

    const { error: updateErr } = await supabase
      .from('questions')
      .update({ status: 'answered' })
      .eq('id', question.id)

    if (updateErr) throw updateErr

    answeringId.value = null
    answerDraft.value[question.id] = ''
    toast.success('Jawaban tersimpan!')
    await fetchQuestions()
  } catch {
    toast.error('Gagal menyimpan jawaban.')
  } finally {
    submittingAnswer.value = false
  }
}

async function updateStatus(id: string, status: Question['status']) {
  const { error } = await supabase.from('questions').update({ status }).eq('id', id)
  if (error) { toast.error('Gagal memperbarui status.'); return }
  const q = questions.value.find(q => q.id === id)
  if (q) q.status = status
}

async function saveProfile() {
  if (!user.value) return
  savingProfile.value = true
  profileSaved.value = false
  profileError.value = ''

  const { error } = await supabase
    .from('profiles')
    .update({
      display_name: profileForm.value.display_name.trim(),
      bio: profileForm.value.bio.trim(),
      is_public: profileForm.value.is_public,
    })
    .eq('id', user.value.id)

  savingProfile.value = false
  if (error) {
    toast.error('Gagal menyimpan. Coba lagi.')
  } else {
    if (profile.value) {
      profile.value.display_name = profileForm.value.display_name.trim()
      profile.value.bio = profileForm.value.bio.trim()
      profile.value.is_public = profileForm.value.is_public
    }
    profileSaved.value = true
    toast.success('Profil berhasil disimpan!')
    setTimeout(() => (profileSaved.value = false), 2500)
  }
}

async function copyLink() {
  await navigator.clipboard.writeText(inboxLink.value)
  copied.value = true
  setTimeout(() => (copied.value = false), 2000)
}

function timeAgo(dateStr: string) {
  const diff = Date.now() - new Date(dateStr).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 1) return 'baru saja'
  if (mins < 60) return `${mins} menit lalu`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `${hours} jam lalu`
  const days = Math.floor(hours / 24)
  return `${days} hari lalu`
}

// ── Realtime ───────────────────────────────────────────────────────────────

function subscribeRealtime() {
  if (!user.value) return
  realtimeChannel = supabase
    .channel('dashboard-questions')
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: 'questions',
        filter: `inbox_owner_id=eq.${user.value.id}`,
      },
      (payload) => {
        const newQ = { ...(payload.new as any), answer: null } as Question
        questions.value.unshift(newQ)
        hasNewQuestion.value = true
      }
    )
    .subscribe()
}

// ── Lifecycle ──────────────────────────────────────────────────────────────

let unwatch: (() => void) | undefined

onMounted(() => {
  let initialized = false
  unwatch = watch(
    user,
    async (newUser) => {
      if (newUser && !initialized) {
        initialized = true
        await Promise.all([fetchQuestions(), fetchProfile()])
        subscribeRealtime()
      }
    },
    { immediate: true }
  )
})

onUnmounted(() => {
  unwatch?.()
  realtimeChannel?.unsubscribe()
})
</script>

<template>
  <div class="min-h-screen bg-gray-50">
    <div class="max-w-3xl mx-auto px-4 py-8">
      <!-- Tab Navigasi -->
      <div class="flex gap-2 mb-6 border-b border-gray-200">
        <button
          @click="activeTab = 'questions'; hasNewQuestion = false"
          class="px-4 py-2 text-sm font-medium transition-colors border-b-2 -mb-px"
          :class="activeTab === 'questions'
            ? 'border-indigo-600 text-indigo-600'
            : 'border-transparent text-gray-500 hover:text-gray-700'"
        >
          Pertanyaan Masuk
          <span
            v-if="hasNewQuestion"
            class="ml-1.5 inline-block w-2 h-2 rounded-full bg-red-500"
          ></span>
        </button>
        <button
          @click="activeTab = 'settings'"
          class="px-4 py-2 text-sm font-medium transition-colors border-b-2 -mb-px"
          :class="activeTab === 'settings'
            ? 'border-indigo-600 text-indigo-600'
            : 'border-transparent text-gray-500 hover:text-gray-700'"
        >
          Pengaturan Profil
        </button>
      </div>

      <!-- ── SECTION: Pertanyaan Masuk ── -->
      <section v-if="activeTab === 'questions'">
        <!-- Filter tabs -->
        <div class="flex gap-2 mb-4">
          <button
            v-for="tab in [
              { key: 'all', label: 'Semua' },
              { key: 'pending', label: 'Pending' },
              { key: 'answered', label: 'Sudah Dijawab' },
            ]"
            :key="tab.key"
            @click="filterTab = tab.key as typeof filterTab"
            class="px-3 py-1 rounded-full text-sm font-medium transition-colors"
            :class="filterTab === tab.key
              ? 'bg-indigo-600 text-white'
              : 'bg-white text-gray-600 border border-gray-300 hover:bg-gray-50'"
          >
            {{ tab.label }}
          </button>
        </div>

        <!-- Loading skeleton -->
        <div v-if="loadingQuestions" class="space-y-3">
          <div
            v-for="i in 3"
            :key="i"
            class="bg-white rounded-2xl shadow p-5 animate-pulse"
          >
            <div class="h-4 bg-gray-200 rounded w-3/4 mb-2"></div>
            <div class="h-3 bg-gray-200 rounded w-1/4"></div>
          </div>
        </div>

        <!-- Empty state -->
        <p
          v-else-if="filteredQuestions.length === 0"
          class="text-center text-gray-400 text-sm py-12"
        >
          Belum ada pertanyaan di sini.
        </p>

        <!-- Question cards -->
        <div v-else class="space-y-4">
          <div
            v-for="q in filteredQuestions"
            :key="q.id"
            class="bg-white rounded-2xl shadow p-5 transition-opacity"
            :class="{ 'opacity-50': q.status === 'hidden' }"
          >
            <!-- Question body -->
            <p class="text-gray-800 font-medium mb-2">{{ q.body }}</p>

            <!-- Meta -->
            <div class="flex items-center gap-2 mb-3">
              <span
                class="text-xs px-2 py-0.5 rounded-full font-medium"
                :class="{
                  'bg-yellow-100 text-yellow-700': q.status === 'pending',
                  'bg-green-100 text-green-700': q.status === 'answered',
                  'bg-gray-100 text-gray-500': q.status === 'hidden',
                }"
              >
                {{ q.status === 'pending' ? 'Pending' : q.status === 'answered' ? 'Dijawab' : 'Disembunyikan' }}
              </span>
              <span class="text-xs text-gray-400">{{ timeAgo(q.submitted_at) }}</span>
            </div>

            <!-- Existing answer -->
            <div
              v-if="q.status === 'answered' && q.answer"
              class="border-l-4 border-indigo-300 pl-3 mb-3"
            >
              <p class="text-sm text-gray-600">{{ q.answer.body }}</p>
            </div>

            <!-- Answer form -->
            <div v-if="answeringId === q.id" class="mt-3">
              <textarea
                v-model="answerDraft[q.id]"
                rows="3"
                placeholder="Tulis jawabanmu..."
                maxlength="1000"
                class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-indigo-500"
              ></textarea>
              <div class="flex gap-2 mt-2">
                <button
                  @click="submitAnswer(q)"
                  :disabled="submittingAnswer || !answerDraft[q.id]?.trim()"
                  class="bg-indigo-600 hover:bg-indigo-700 disabled:bg-indigo-300 text-white text-sm font-medium px-4 py-1.5 rounded-lg transition-colors"
                >
                  {{ submittingAnswer ? 'Menyimpan...' : 'Simpan Jawaban' }}
                </button>
                <button
                  @click="answeringId = null"
                  class="text-sm text-gray-500 hover:text-gray-700 px-3 py-1.5"
                >
                  Batal
                </button>
              </div>
            </div>

            <!-- Actions -->
            <div class="flex gap-2 mt-3 flex-wrap">
              <template v-if="q.status === 'pending'">
                <button
                  @click="toggleAnswerForm(q.id)"
                  class="text-sm text-indigo-600 hover:text-indigo-800 font-medium"
                >
                  {{ answeringId === q.id ? 'Tutup' : 'Jawab' }}
                </button>
                <button
                  @click="updateStatus(q.id, 'hidden')"
                  class="text-sm text-gray-400 hover:text-gray-600"
                >
                  Sembunyikan
                </button>
              </template>

              <template v-else-if="q.status === 'hidden'">
                <button
                  @click="updateStatus(q.id, 'pending')"
                  class="text-sm text-indigo-600 hover:text-indigo-800 font-medium"
                >
                  Tampilkan Lagi
                </button>
              </template>
            </div>
          </div>
        </div>
      </section>

      <!-- ── SECTION: Pengaturan Profil ── -->
      <section v-else-if="activeTab === 'settings'">
        <div v-if="loadingProfile" class="bg-white rounded-2xl shadow p-6 animate-pulse space-y-4">
          <div class="h-4 bg-gray-200 rounded w-1/3"></div>
          <div class="h-8 bg-gray-200 rounded"></div>
          <div class="h-16 bg-gray-200 rounded"></div>
        </div>

        <div v-else-if="profile" class="bg-white rounded-2xl shadow p-6 space-y-5">
          <!-- Link profil -->
          <div>
            <p class="text-sm font-medium text-gray-700 mb-1">Link profil publikmu</p>
            <div class="flex items-center gap-2">
              <code class="flex-1 text-xs bg-gray-100 rounded px-3 py-2 text-gray-600 truncate">
                {{ inboxLink }}
              </code>
              <button
                @click="copyLink"
                class="text-sm text-indigo-600 hover:text-indigo-800 font-medium whitespace-nowrap"
              >
                {{ copied ? 'Disalin!' : 'Salin' }}
              </button>
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Display Name</label>
            <input
              v-model="profileForm.display_name"
              type="text"
              class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500"
            />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Bio</label>
            <textarea
              v-model="profileForm.bio"
              rows="3"
              placeholder="Ceritakan sedikit tentang dirimu..."
              class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-indigo-500"
            ></textarea>
          </div>

          <div class="flex items-center gap-3">
            <button
              @click="profileForm.is_public = !profileForm.is_public"
              class="relative inline-flex h-6 w-11 items-center rounded-full transition-colors"
              :class="profileForm.is_public ? 'bg-indigo-600' : 'bg-gray-300'"
            >
              <span
                class="inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform"
                :class="profileForm.is_public ? 'translate-x-6' : 'translate-x-1'"
              ></span>
            </button>
            <span class="text-sm text-gray-700">Profil publik (bisa ditemukan orang lain)</span>
          </div>

          <p v-if="profileError" class="text-sm text-red-500">{{ profileError }}</p>

          <button
            @click="saveProfile"
            :disabled="savingProfile"
            class="w-full bg-indigo-600 hover:bg-indigo-700 disabled:bg-indigo-300 text-white font-medium py-2 px-4 rounded-lg text-sm transition-colors"
          >
            {{ savingProfile ? 'Menyimpan...' : profileSaved ? 'Tersimpan!' : 'Simpan Perubahan' }}
          </button>
        </div>
      </section>

    </div>
  </div>
</template>
