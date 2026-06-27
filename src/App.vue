<script setup lang="ts">
import AppNavbar from '@/components/AppNavbar.vue'
import ToastContainer from '@/components/ToastContainer.vue'
</script>

<template>
  <AppNavbar />
  <RouterView />
  <ToastContainer />
</template>
