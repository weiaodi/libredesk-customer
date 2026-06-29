<template>
  <!-- Search route: full-width, no panels -->
  <div v-if="isSearchRoute" class="h-screen w-full">
    <router-view v-slot="{ Component }">
      <keep-alive>
        <component :is="Component" />
      </keep-alive>
    </router-view>
  </div>

  <!-- Mobile: Stack navigation (show either list or detail) -->
  <div v-else-if="isMobile" class="h-full w-full flex flex-col overflow-hidden">
    <!-- Conversation list (shown when no conversation is open) -->
    <ConversationList v-if="!isConversationOpen" />

    <!-- Conversation detail (shown when a conversation is open) -->
    <router-view v-else v-slot="{ Component }">
      <keep-alive>
        <component :is="Component" />
      </keep-alive>
    </router-view>
  </div>

  <!-- Desktop: Resizable panel layout -->
  <ResizablePanelGroup
    v-else
    direction="horizontal"
    class="h-screen w-full"
    @layout="onLayoutChange"
  >
    <!-- Conversation List Panel -->
    <ResizablePanel :default-size="panelSizes[0]" :min-size="20" :max-size="45">
      <ConversationList />
    </ResizablePanel>

    <ResizableHandle />

    <!-- Conversation Detail Panel -->
    <ResizablePanel :default-size="panelSizes[1]" :min-size="30">
      <router-view v-slot="{ Component }">
        <keep-alive>
          <component :is="Component" />
        </keep-alive>
      </router-view>
    </ResizablePanel>
  </ResizablePanelGroup>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import { useStorage } from '@vueuse/core'
import { useIsMobile } from '@/composables/useIsMobile'
import { useConversationStore } from '@/stores/conversation'
import ConversationList from '@/features/conversation/list/ConversationList.vue'
import {
  ResizablePanelGroup,
  ResizablePanel,
  ResizableHandle
} from '@shared-ui/components/ui/resizable'

defineOptions({ name: 'InboxLayout' })

const route = useRoute()
const isMobile = useIsMobile()
const conversationStore = useConversationStore()
const isSearchRoute = computed(() => route.name === 'search')

// On mobile, show conversation detail only when route has a UUID param.
// Do NOT use conversationStore.isConversationOpen here - it stays true
// even after navigating away, which would hide the list permanently.
const isConversationOpen = computed(() => {
  return !!route.params.uuid
})

// Persist panel sizes: [conversationList, conversationDetail]
const panelSizes = useStorage('inboxPanelSizes', [25, 75])

const onLayoutChange = (sizes) => {
  panelSizes.value = sizes
}
</script>
