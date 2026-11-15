//
//  EditProfileView.swift
//  Odyssey
//
//  Edit profile. Take or choose a profile photo (or go back to the default
//  person), change your name, handle, bio and city, and equip any frame,
//  effect, banner, title or badge you own. Locked items send you to the
//  shop instead of failing silently. Ported from edit-profile.js.
//

import Foundation
import PhotosUI
import SwiftUI
import UIKit

struct EditProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(ToastCenter.self) private var toast

    @State private var name = ""
    @State private var handle = ""
    @State private var bio = ""
    @State private var city = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 0) {
            NavHeader(title: "Edit profile", back: { router.pop() }) {
                Button("Save", action: save).buttonStyle(.pill(.primary, height: 36))
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    avatarBlock
                    EditProfilePickers(onLocked: locked)
                    fields
                    Color.clear.frame(height: 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Palette.surface)
        .onAppear(perform: load)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    usePhoto(image)
                }
                photoItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            EditProfileCamera { image in
                if let image { usePhoto(image) }
                showCamera = false
            }
            .ignoresSafeArea()
        }
    }

    private var avatarBlock: some View {
        VStack(spacing: 12) {
            ProfileBannerView(id: store.state.equipped.banner, showLabel: false)
                .frame(height: 130)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
                .overlay(alignment: .bottom) {
                    AvatarView(person: store.me, size: 104)
                        .padding(5)
                        .background(Palette.surface, in: Circle())
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                .frame(width: 32, height: 32).background(Palette.ink, in: Circle())
                                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                        }
                        .offset(y: 60)
                }
                .padding(.bottom, 64)
            HStack(spacing: 8) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Upload photo", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.pill(.primary, height: 36))
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { showCamera = true } label: { Label("Take photo", systemImage: "camera") }
                        .buttonStyle(.pill(.soft, height: 36))
                }
                if store.state.user.avatar.kind == "none" {
                    Button("Use sample photo") {
                        store.update { s in s.user.avatar = Avatar(kind: "photo", value: s.user.sampleSelfie) }
                    }
                    .buttonStyle(.pill(.soft, height: 36))
                } else {
                    Button("Remove") {
                        store.update { s in s.user.avatar = Avatar(kind: "none", value: nil) }
                    }
                    .buttonStyle(.pill(.soft, height: 36))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Name")
            FieldBox { TextField("Your name", text: $name).textInputAutocapitalization(.words) }
            label("Handle")
            FieldBox {
                Text("@").foregroundStyle(Palette.muted)
                TextField("handle", text: $handle).textInputAutocapitalization(.never).autocorrectionDisabled()
            }
            label("Bio")
            TextField("A line about how you explore", text: $bio, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .padding(Space.s4)
                .background(Palette.surface2, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            label("City")
            FieldBox(icon: "location") { TextField("City", text: $city) }
        }
        .font(.system(size: 15))
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    private func label(_ text: String) -> some View {
        Text(text).labelStyle().padding(.top, 8)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let user = store.state.user
        name = user.name
        handle = user.handle
        bio = user.bio
        city = user.city
    }

    private func save() {
        let cleanHandle = handle.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" }
        store.update { s in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { s.user.name = String(trimmed.prefix(40)) }
            if !cleanHandle.isEmpty { s.user.handle = String(cleanHandle.prefix(24)) }
            s.user.bio = String(bio.trimmingCharacters(in: .whitespacesAndNewlines).prefix(140))
            let place = city.trimmingCharacters(in: .whitespacesAndNewlines)
            if !place.isEmpty { s.user.city = place }
        }
        toast.show("Profile saved", icon: "check")
        router.pop()
    }

    private func usePhoto(_ image: UIImage) {
        guard let file = PhotoStore.save(image, prefix: "avatar", maxSide: 800) else { return }
        store.update { s in s.user.avatar = Avatar(kind: "local", value: file) }
        Cloud.shared.uploadAvatar(file: file)
        toast.show("Photo updated", icon: "check")
    }

    private func locked(_ type: CosmeticType) {
        toast.show("Unlock this in the shop", icon: "lock")
        router.push(.shop(type.rawValue))
    }
}

/// The system camera, for a quick profile selfie.
struct EditProfileCamera: UIViewControllerRepresentable {
    var done: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraDevice = .front
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (UIImage?) -> Void
        init(done: @escaping (UIImage?) -> Void) { self.done = done }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            done(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}
