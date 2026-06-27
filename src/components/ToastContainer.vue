<script setup lang="ts">
import { useToast } from '@/composables/useToast'

const { toasts, dismiss } = useToast()
</script>

<template>
  <div class="fixed bottom-4 right-4 z-50 flex flex-col gap-2 pointer-events-none">
    <Transition
      v-for="toast in toasts"
      :key="toast.id"
      enter-active-class="transition-all duration-300"
      enter-from-class="opacity-0 translate-y-2"
      enter-to-class="opacity-100 translate-y-0"
      leave-active-class="transition-all duration-200"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        class="flex items-center gap-3 px-4 py-3 rounded-xl shadow-lg text-sm font-medium pointer-events-auto cursor-pointer"
        :class="toast.type === 'success'
          ? 'bg-green-600 text-white'
          : 'bg-red-600 text-white'"
        @click="dismiss(toast.id)"
      >
        <span>{{ toast.type === 'success' ? '✓' : '✕' }}</span>
        <span>{{ toast.message }}</span>
      </div>
    </Transition>
  </div>
</template>
