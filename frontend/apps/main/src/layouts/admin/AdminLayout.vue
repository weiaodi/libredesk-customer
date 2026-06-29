<template>
  <div class="overflow-y-auto h-full">
    <div class="p-3 sm:p-6 md:p-8 min-h-full flex flex-col">
      <div
        class="flex flex-col items-center justify-center flex-grow"
        v-if="$route.name === 'admin'"
      >
        <div>{{ $t('admin.empty') }}</div>
      </div>
      <router-view class="flex-grow" />
    </div>
  </div>
</template>
