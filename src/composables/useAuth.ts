import { ref, computed } from 'vue'
import { supabase } from '@/lib/supabase'
import type { User } from '@supabase/supabase-js'

const user = ref<User | null>(null)

supabase.auth.getUser().then(({ data }) => {
  user.value = data.user
})

supabase.auth.onAuthStateChange((_event, session) => {
  user.value = session?.user ?? null
})

export function useAuth() {
  const isLoggedIn = computed(() => !!user.value)

  async function login(email: string, password: string) {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) throw error
    user.value = data.user
  }

  async function register(email: string, password: string, username: string, displayName: string) {
    const { data: existing } = await supabase
      .from('profiles')
      .select('id')
      .eq('username', username)
      .maybeSingle()

    if (existing) throw new Error('Username sudah dipakai')

    // Pass username & display_name as metadata — trigger handle_new_user reads them
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { username, display_name: displayName } },
    })
    if (error) throw error
    if (!data.user) throw new Error('Registrasi gagal')

    user.value = data.user
  }

  async function logout() {
    const { error } = await supabase.auth.signOut()
    if (error) throw error
    user.value = null
  }

  return { user, isLoggedIn, login, register, logout }
}
