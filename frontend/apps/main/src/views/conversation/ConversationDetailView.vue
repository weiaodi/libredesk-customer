<template>
  <div class="relative h-full">
    <div
      v-if="isLoading"
      class="conv-progress absolute inset-x-0 top-0 h-0.5 z-50 pointer-events-none"
    />

    <!-- Mobile: Full-width conversation, sidebar as Sheet drawer -->
    <template v-if="isMobile && showContent">
      <Conversation class="h-full" />

      <!-- Mobile sidebar toggle button -->
      <button
        @click="mobileSidebarOpen = true"
        class="absolute right-2 top-1 p-2 rounded-md bg-sidebar text-sidebar-foreground hover:bg-sidebar-accent transition-all border shadow z-50"
      >
        <PanelRight size="16" />
      </button>

      <!-- Mobile sidebar as Sheet -->
      <Sheet :open="mobileSidebarOpen" @update:open="mobileSidebarOpen = $event">
        <SheetContent side="right" class="w-[85vw] max-w-sm p-0">
          <SheetHeader class="px-4 pt-4 pb-2">
            <SheetTitle>{{ $t('conversation.sidebar.information') }}</SheetTitle>
          </SheetHeader>
          <div class="h-full overflow-y-auto overflow-x-hidden px-2 pb-16">
            <ConversationSideBar />
          </div>
        </SheetContent>
      </Sheet>
    </template>

    <!-- Desktop: Resizable panel layout -->
    <ResizablePanelGroup
      v-else-if="showContent"
      direction="horizontal"
      class="h-full transition-opacity duration-200"
      :class="{ 'opacity-60': isDimmed }"
      :inert="isDimmed"
      @layout="onLayoutChange"
    >
      <!-- Conversation Content Panel -->
      <ResizablePanel :default-size="sidebarOpen ? panelSizes[0] : 100" :min-size="40">
        <Conversation />
      </ResizablePanel>

      <!-- Resizable Handle -->
      <ResizableHandle />

      <!-- Sidebar Panel (collapsible) -->
      <ResizablePanel
        ref="sidebarPanelRef"
        :default-size="panelSizes[1]"
        :min-size="15"
        :max-size="40"
        :collapsible="true"
        :collapsed-size="0"
        @collapse="onSidebarCollapse"
        @expand="onSidebarExpand"
      >
        <div class="h-full overflow-y-auto overflow-x-hidden">
          <ConversationSideBar />
        </div>
      </ResizablePanel>
    </ResizablePanelGroup>

    <!-- Toggle button when sidebar is collapsed (desktop only) -->
    <button
      v-if="showContent && !sidebarOpen && !isMobile"
      @click="toggleSidebar"
      class="absolute right-0 top-16 p-2 rounded-l-full bg-sidebar text-sidebar-foreground hover:bg-opacity-90 transition-all duration-200 border shadow hover:scale-105 z-50"
    >
      <ChevronLeft size="16" />
    </button>
  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted, onUnmounted, nextTick } from 'vue'
import { useRoute } from 'vue-router'
import { useStorage, useDocumentVisibility } from '@vueuse/core'
import { ChevronLeft, PanelRight } from 'lucide-vue-next'
import { useIsMobile } from '@/composables/useIsMobile'
import { useConversationStore } from '@main/stores/conversation'
import { useEmitter } from '@main/composables/useEmitter'
import { EMITTER_EVENTS } from '@main/constants/emitterEvents.js'
import Conversation from '@main/features/conversation/Conversation.vue'
import ConversationSideBar from '@main/features/conversation/sidebar/ConversationSideBar.vue'
import { ResizablePanelGroup, ResizablePanel, ResizableHandle } from '@shared-ui/components/ui/resizable'
import { Sheet, SheetContent, SheetHeader, SheetTitle } from '@shared-ui/components/ui/sheet'

const props = defineProps({
  uuid: String
})

const conversationStore = useConversationStore()
const route = useRoute()
const emitter = useEmitter()
const isMobile = useIsMobile()
const sidebarPanelRef = ref(null)
const sidebarOpen = useStorage('conversationSidebarOpen', true)
const panelSizes = useStorage('conversationDetailPanelSizes', [70, 30])
const mobileSidebarOpen = ref(false)

const showContent = computed(
  () => conversationStore.current || conversationStore.conversation.loading
)

const isLoading = computed(
  () => conversationStore.conversation.loading || conversationStore.messages.loading
)

const isDimmed = computed(() => conversationStore.conversation.loading)

const toggleSidebar = () => {
  if (sidebarOpen.value) {
    sidebarPanelRef.value?.collapse()
  } else {
    sidebarPanelRef.value?.expand()
  }
}

const onSidebarCollapse = () => {
  sidebarOpen.value = false
}

const onSidebarExpand = () => {
  sidebarOpen.value = true
}

const onLayoutChange = (sizes) => {
  if (sidebarOpen.value && sizes.length === 2) {
    panelSizes.value = sizes
  }
}

// Listen to emitter events for toggle (from sidebar contact)
onMounted(() => {
  emitter.on(EMITTER_EVENTS.CONVERSATION_SIDEBAR_TOGGLE, toggleSidebar)

  // Sync initial collapsed state from localStorage
  nextTick(() => {
    if (!sidebarOpen.value && sidebarPanelRef.value && !isMobile.value) {
      sidebarPanelRef.value.collapse()
    }
  })
})

const visibility = useDocumentVisibility()
watch(visibility, (state) => {
  if (state === 'visible' && props.uuid) {
    conversationStore.updateAssigneeLastSeen(props.uuid)
  }
})

onUnmounted(() => {
  emitter.off(EMITTER_EVENTS.CONVERSATION_SIDEBAR_TOGGLE, toggleSidebar)
})

const fetchConversation = async (uuid) => {
  await Promise.all([
    conversationStore.fetchConversation(uuid),
    conversationStore.fetchMessages(uuid)
  ])
  await conversationStore.updateAssigneeLastSeen(uuid)
}

// Initial fetch
onMounted(() => {
  if (props.uuid) fetchConversation(props.uuid)
})

watch(
  () => props.uuid,
  (newUUID, oldUUID) => {
    if (!newUUID || newUUID === oldUUID) return
    const canTransition = oldUUID && !route.query.scrollTo && typeof document.startViewTransition === 'function'
    if (!canTransition) {
      fetchConversation(newUUID)
      return
    }
    const transition = document.startViewTransition(async () => {
      fetchConversation(newUUID)
      await nextTick()
    })
    transition.ready.catch(() => {})
    transition.finished.catch(() => {})
  }
)
</script>

<style scoped>
.conv-progress {
  background-color: hsl(var(--primary) / 0.4);
  animation: conv-progress-pulse 2.4s ease-in-out infinite;
}

@keyframes conv-progress-pulse {
  0%, 100% { opacity: 0.4; }
  50% { opacity: 1; }
}
</style>
