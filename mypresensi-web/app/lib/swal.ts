// app/lib/swal.ts
// SweetAlert2 wrapper dengan styling konsisten MyPresensi design system.

import Swal from 'sweetalert2'

// Base Swal dengan styling MyPresensi
export const swal = Swal.mixin({
  customClass: {
    confirmButton: 'swal-btn-confirm',
    cancelButton: 'swal-btn-cancel',
    popup: 'swal-popup-custom',
    title: 'swal-title-custom',
    htmlContainer: 'swal-html-custom',
  },
  buttonsStyling: false,
  reverseButtons: true,
})

// Toast notification (auto-dismiss, top-right)
export const toast = Swal.mixin({
  toast: true,
  position: 'top-end',
  showConfirmButton: false,
  timer: 3000,
  timerProgressBar: true,
  didOpen: (t) => {
    t.onmouseenter = Swal.stopTimer
    t.onmouseleave = Swal.resumeTimer
  },
})

// Re-export untuk akses Swal.showLoading() dll
export { Swal }
