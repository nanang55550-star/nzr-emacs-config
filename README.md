# nzr-emacs-config

A lightweight, high-performance Emacs configuration optimized specifically for **Linux** and **Termux (Android)** environments.

---

## 🚀 Features / Fitur

### 🇮🇩 Bahasa Indonesia

Konfigurasi ini dirancang agar Emacs berjalan secepat kilat tanpa lag, baik di perangkat spesifikasi rendah (HP) maupun PC desktop:

- **Performa:** Menggunakan **GCMH** (Garbage Collector Magic Hack) untuk manajemen RAM pintar saat mengetik, serta **Auto Byte-Compile** latar belakang agar eksekusi kode 30-60% lebih cepat.
- **Visual:** Tampilan minimalis berlatar belakang hitam pekat (*Wombat Black*) dipadukan dengan **Powerline Cache** (widget sistem anti-lag yang memantau RAM/CPU/Disk).
- **Coding:** Dukungan penuh untuk *auto-completion* (**Company**), pengecek eror *real-time* (**Flycheck**), cuplikan kode cepat (**Yasnippet**), dan garis indentasi pelangi (**Highlight Indent Guides**).
- **Navigasi:** Navigasi panel cepat menggunakan `Alt + Tombol Panah` (**Windmove**) dan fungsi tombol `F2` hingga `F12` untuk produktivitas harian.

### 🇬🇧 English

This configuration is tuned to make Emacs lightning-fast and lag-free, whether on mobile (Termux) or desktop environments:

- **Performance:** Powered by **GCMH** (Garbage Collector Magic Hack) for dynamic RAM management while typing, and background **Auto Byte-Compilation** for 30-60% faster code execution.
- **Visuals:** Distraction-free, pure black theme (*Wombat Black*) paired with a custom **cached Powerline** system widget (RAM/CPU/Disk monitor) that prevents typing stutter.
- **Coding:** Fully equipped with modern IDE features: auto-completion (**Company**), real-time syntax checking (**Flycheck**), snippets expansion (**Yasnippet**), and rainbow indentation lines (**Highlight Indent Guides**).
- **Navigation:** Quick window switching via `Alt + Arrow Keys` (**Windmove**) and productivity-focused mappings for function keys (`F2` to `F12`).

---

## ⚠️ Important Notes / Catatan Penting

> 💡 **Internet Required (Diperlukan Internet):** 
> 
> Kamu memerlukan koneksi internet aktif pada **kali pertama** menjalankan Emacs ini karena sistem akan mengunduh semua plugin secara otomatis dari MELPA.
>
> You will need an active internet connection on the **very first run** as Emacs will automatically download and install all the required packages from MELPA.

---

## 🛠️ Installation & Usage / Instalasi & Penggunaan

### 🇮🇩 Cara Install

Kamu bisa langsung menyalin file `.emacs` ke direktori *home* kamu di Linux/Termux.

#### Cara Cepat (Rekomendasi) 🚀

Buka terminal Linux kamu dan jalankan perintah satu baris ini:

```bash
curl -fLo ~/.emacs https://raw.githubusercontent.com/nanang55550-star/nzr-emacs-config/main/.emacs
```

#### Cara Manual (Via Nano)

1. Buka terminal lalu jalankan:
   ```bash
   nano ~/.emacs
   ```

2. Salin seluruh teks kode dari file `.emacs` di repositori ini, lalu tempel (paste) ke dalam terminal.

3. Simpan dengan menekan `Ctrl + O`, lalu keluar dengan `Ctrl + X`.

---

### 🇬🇧 How to Install

You can easily place the `.emacs` file directly into your home directory.

#### Quick Method (Recommended) 🚀

Open your terminal and run this single-line command:

```bash
curl -fLo ~/.emacs https://raw.githubusercontent.com/nanang55550-star/nzr-emacs-config/main/.emacs
```

#### Manual Method (Via Nano)

1. Open your terminal and run:
   ```bash
   nano ~/.emacs
   ```

2. Copy the entire script from the `.emacs` file in this repository and paste it into your terminal.

3. Save by pressing `Ctrl + O`, then exit via `Ctrl + X`.

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 👤 Author

Created with ⚡ by **NZR**
