<script setup lang="ts">
import { useRoute } from 'vue-router'

const route = useRoute()
const username = route.params.username
</script>

<template>
  <h1>Inbox: {{ username }}</h1>
</template>
