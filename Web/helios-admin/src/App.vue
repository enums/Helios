<script setup>
import { RouterLink, RouterView } from 'vue-router'
import NavigationBar from './components/NavigationBar.vue';
</script>

<template>
  <el-container class="main">
    <el-header class="header">Header</el-header>
    <el-container>
      <el-aside class="navi">
        <NavigationBar />
      </el-aside>
      <el-container>
        <el-main>
          <RouterView />
        </el-main>
      </el-container>
    </el-container>
    <el-footer class="footer">Footer</el-footer>
  </el-container>
</template>

<style scoped>
.navi {
  width: 12rem;
  padding-top: 20px;
}

.main {
  display: flex;
  width: 100%;
  height: 100vh;
}

header,
footer {
  background-color: #b3c0d1;
}
</style>
